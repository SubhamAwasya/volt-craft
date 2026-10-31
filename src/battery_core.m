#import "battery_core.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define HELPER_SOCKET_PATH "/var/run/voltcraft_helper.sock"

// --- Helper IPC Client Implementation ---
BOOL isHelperInstalledAndRunning(void) {
    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    if (s < 0) return NO;

    struct timeval tv = { .tv_sec = 0, .tv_usec = 300000 };
    setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, HELPER_SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (connect(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(s);
        return NO;
    }

    const char *cmd = "PING\n";
    write(s, cmd, strlen(cmd));

    char buf[64] = {0};
    ssize_t n = read(s, buf, sizeof(buf) - 1);
    close(s);

    return (n > 0 && strstr(buf, "PONG") != NULL);
}

BOOL sendHelperCommand(const char *cmd, char *outResp, size_t maxLen) {
    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    if (s < 0) return NO;

    struct timeval tv = { .tv_sec = 1, .tv_usec = 0 };
    setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, HELPER_SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (connect(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(s);
        return NO;
    }

    char fullCmd[256];
    snprintf(fullCmd, sizeof(fullCmd), "%s\n", cmd);
    write(s, fullCmd, strlen(fullCmd));

    if (outResp && maxLen > 0) {
        memset(outResp, 0, maxLen);
        read(s, outResp, maxLen - 1);
    }
    close(s);
    return YES;
}

// --- SMC Structures ---
typedef struct {
    uint8_t major;
    uint8_t minor;
    uint8_t build;
    uint8_t reserved[1];
    uint16_t release;
} SMCKeyData_vers_t;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t dataAttributes;
} SMCKeyData_keyInfo_t;

typedef struct {
    uint32_t key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    uint8_t result;
    uint8_t status;
    uint8_t data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCParamStruct;

#define KERNEL_INDEX_SMC 2
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_READ_KEYINFO 9

#define HISTORY_POINTS 20

static VoltCraftConfig gConfig;
static BOOL gConfigInitialized = NO;
static IOPMAssertionID gSleepAssertion = kIOPMNullAssertionID;

static float sTempHistory[HISTORY_POINTS];
static float sPowerHistory[HISTORY_POINTS];
static float sSocHistory[HISTORY_POINTS];
static int sHistoryIndex = 0;

static uint32_t strToKey(const char *str) {
    uint32_t key = 0;
    for (int i = 0; i < 4 && str[i]; i++) {
        key = (key << 8) | ((uint8_t)str[i]);
    }
    return key;
}

float readBatteryTemperatureFromSMC(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return 30.0f;

    io_connect_t connection;
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    if (kr != kIOReturnSuccess) return 30.0f;

    SMCParamStruct input;
    SMCParamStruct output;
    size_t outputSize = sizeof(output);

    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = strToKey("TB0T");
    input.data8 = SMC_CMD_READ_KEYINFO;

    kr = IOConnectCallStructMethod(connection, KERNEL_INDEX_SMC, &input, sizeof(input), &output, &outputSize);
    if (kr != kIOReturnSuccess || output.result != 0) {
        IOServiceClose(connection);
        return 30.0f;
    }

    uint32_t dataSize = output.keyInfo.dataSize;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = strToKey("TB0T");
    input.keyInfo.dataSize = dataSize;
    input.data8 = SMC_CMD_READ_BYTES;

    kr = IOConnectCallStructMethod(connection, KERNEL_INDEX_SMC, &input, sizeof(input), &output, &outputSize);
    IOServiceClose(connection);

    if (kr == kIOReturnSuccess && output.result == 0 && dataSize == 4) {
        float temp = 0.0f;
        memcpy(&temp, output.bytes, sizeof(float));
        if (temp > 10.0f && temp < 80.0f) return temp;
    }
    return 30.0f;
}

// --- PowerUI Client Singleton ---
static id getPowerUIClient(void) {
    static id sClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PowerUI.framework"];
        if ([bundle load]) {
            Class clientClass = NSClassFromString(@"PowerUISmartChargeClient");
            if (clientClass) {
                SEL initSel = NSSelectorFromString(@"initWithClientName:");
                if ([clientClass instancesRespondToSelector:initSel]) {
                    id obj = [clientClass alloc];
                    sClient = ((id (*)(id, SEL, id))objc_msgSend)(obj, initSel, @"VoltCraftPro");
                }
            }
        }
    });
    return sClient;
}

static void notifySmartChargingChanged(void) {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.apple.smartcharging.defaultschanged"),
        NULL,
        NULL,
        TRUE
    );
}

static NSString *getConfigFilePath(void) {
    return @"/tmp/voltcraft_pro_config.json";
}

static inline void ensureConfigLoaded(void) {
    if (!gConfigInitialized) {
        loadProConfig();
    }
}

VoltCraftConfig *getProConfig(void) {
    ensureConfigLoaded();
    return &gConfig;
}

void loadProConfig(void) {
    gConfig.chargeLimit = 80;
    gConfig.allowBelow80 = YES;
    gConfig.sailingEnabled = NO;
    gConfig.sailingDifference = 5;
    gConfig.heatProtectionEnabled = YES;
    gConfig.maxTemperatureC = 35.0f;
    gConfig.stopOnSleep = YES;
    gConfig.stopOnClose = YES;
    gConfig.launchAtLogin = NO;
    gConfig.isDischarging = NO;
    gConfig.isTopUpActive = NO;
    gConfig.isSailingCurrently = NO;
    gConfig.isHeatPaused = NO;
    gConfig.sleepPrevented = NO;
    gConfig.calibrationPhase = CalibrationPhaseIdle;

    // Menu Bar Icon Defaults
    gConfig.iconShowPercentage = YES;
    gConfig.iconShowGlyphs = YES;
    gConfig.iconShowPercentSign = NO;
    gConfig.iconHighContrastBorder = YES;
    gConfig.iconWidth = 36;
    gConfig.iconColorMode = 0;

    NSData *data = [NSData dataWithContentsOfFile:getConfigFilePath()];
    if (data) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([dict isKindOfClass:[NSDictionary class]]) {
            if (dict[@"chargeLimit"]) gConfig.chargeLimit = [dict[@"chargeLimit"] intValue];
            if (dict[@"allowBelow80"]) gConfig.allowBelow80 = [dict[@"allowBelow80"] boolValue];
            if (dict[@"sailingEnabled"]) gConfig.sailingEnabled = [dict[@"sailingEnabled"] boolValue];
            if (dict[@"sailingDifference"]) gConfig.sailingDifference = [dict[@"sailingDifference"] intValue];
            if (dict[@"heatProtectionEnabled"]) gConfig.heatProtectionEnabled = [dict[@"heatProtectionEnabled"] boolValue];
            if (dict[@"maxTemperatureC"]) gConfig.maxTemperatureC = [dict[@"maxTemperatureC"] floatValue];
            if (dict[@"stopOnSleep"]) gConfig.stopOnSleep = [dict[@"stopOnSleep"] boolValue];
            if (dict[@"stopOnClose"]) gConfig.stopOnClose = [dict[@"stopOnClose"] boolValue];
            if (dict[@"launchAtLogin"]) gConfig.launchAtLogin = [dict[@"launchAtLogin"] boolValue];
            if (dict[@"isDischarging"]) gConfig.isDischarging = [dict[@"isDischarging"] boolValue];
            if (dict[@"isTopUpActive"]) gConfig.isTopUpActive = [dict[@"isTopUpActive"] boolValue];
            if (dict[@"sleepPrevented"]) gConfig.sleepPrevented = [dict[@"sleepPrevented"] boolValue];

            if (dict[@"iconShowPercentage"]) gConfig.iconShowPercentage = [dict[@"iconShowPercentage"] boolValue];
            if (dict[@"iconShowGlyphs"]) gConfig.iconShowGlyphs = [dict[@"iconShowGlyphs"] boolValue];
            if (dict[@"iconShowPercentSign"]) gConfig.iconShowPercentSign = [dict[@"iconShowPercentSign"] boolValue];
            if (dict[@"iconHighContrastBorder"]) gConfig.iconHighContrastBorder = [dict[@"iconHighContrastBorder"] boolValue];
            if (dict[@"iconWidth"]) gConfig.iconWidth = [dict[@"iconWidth"] intValue];
            if (dict[@"iconColorMode"]) gConfig.iconColorMode = [dict[@"iconColorMode"] intValue];
        }
    }

    if (gConfig.chargeLimit < 20 || gConfig.chargeLimit > 100) gConfig.chargeLimit = 80;
    if (gConfig.sailingDifference < 1 || gConfig.sailingDifference > 15) gConfig.sailingDifference = 5;
    if (gConfig.maxTemperatureC < 30.0f || gConfig.maxTemperatureC > 50.0f) gConfig.maxTemperatureC = 35.0f;
    if (gConfig.iconWidth < 26 || gConfig.iconWidth > 46) gConfig.iconWidth = 36;

    // Initialize history buffers
    for (int i = 0; i < HISTORY_POINTS; i++) {
        sTempHistory[i] = 30.0f;
        sPowerHistory[i] = 28.0f;
        sSocHistory[i] = 88.0f;
    }

    gConfigInitialized = YES;
}

void saveProConfig(void) {
    NSDictionary *dict = @{
        @"chargeLimit": @(gConfig.chargeLimit),
        @"allowBelow80": @(gConfig.allowBelow80),
        @"sailingEnabled": @(gConfig.sailingEnabled),
        @"sailingDifference": @(gConfig.sailingDifference),
        @"heatProtectionEnabled": @(gConfig.heatProtectionEnabled),
        @"maxTemperatureC": @(gConfig.maxTemperatureC),
        @"stopOnSleep": @(gConfig.stopOnSleep),
        @"stopOnClose": @(gConfig.stopOnClose),
        @"launchAtLogin": @(gConfig.launchAtLogin),
        @"isDischarging": @(gConfig.isDischarging),
        @"isTopUpActive": @(gConfig.isTopUpActive),
        @"sleepPrevented": @(gConfig.sleepPrevented),
        @"iconShowPercentage": @(gConfig.iconShowPercentage),
        @"iconShowGlyphs": @(gConfig.iconShowGlyphs),
        @"iconShowPercentSign": @(gConfig.iconShowPercentSign),
        @"iconHighContrastBorder": @(gConfig.iconHighContrastBorder),
        @"iconWidth": @(gConfig.iconWidth),
        @"iconColorMode": @(gConfig.iconColorMode)
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        [data writeToFile:getConfigFilePath() atomically:YES];
    }
}

static void notifyIconConfigChanged(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kVoltCraftIconConfigChangedNotification object:nil];
    });
}

void setIconShowPercentage(BOOL show) {
    ensureConfigLoaded();
    gConfig.iconShowPercentage = show;
    saveProConfig();
    notifyIconConfigChanged();
}

void setIconShowGlyphs(BOOL show) {
    ensureConfigLoaded();
    gConfig.iconShowGlyphs = show;
    saveProConfig();
    notifyIconConfigChanged();
}

void setIconShowPercentSign(BOOL show) {
    ensureConfigLoaded();
    gConfig.iconShowPercentSign = show;
    saveProConfig();
    notifyIconConfigChanged();
}

void setIconHighContrastBorder(BOOL show) {
    ensureConfigLoaded();
    gConfig.iconHighContrastBorder = show;
    saveProConfig();
    notifyIconConfigChanged();
}

void setIconWidth(int width) {
    ensureConfigLoaded();
    if (width < 26) width = 26;
    if (width > 46) width = 46;
    gConfig.iconWidth = width;
    saveProConfig();
    notifyIconConfigChanged();
}

void setIconColorMode(int mode) {
    ensureConfigLoaded();
    gConfig.iconColorMode = mode;
    saveProConfig();
    notifyIconConfigChanged();
}

void resetProConfig(void) {
    gConfig.chargeLimit = 80;
    gConfig.allowBelow80 = YES;
    gConfig.sailingEnabled = NO;
    gConfig.sailingDifference = 5;
    gConfig.heatProtectionEnabled = YES;
    gConfig.maxTemperatureC = 35.0f;
    gConfig.stopOnSleep = YES;
    gConfig.stopOnClose = YES;
    gConfig.launchAtLogin = NO;
    gConfig.isDischarging = NO;
    gConfig.isTopUpActive = NO;
    gConfig.isSailingCurrently = NO;
    gConfig.isHeatPaused = NO;
    gConfig.sleepPrevented = NO;
    gConfig.calibrationPhase = CalibrationPhaseIdle;
    if (gSleepAssertion != kIOPMNullAssertionID) {
        IOPMAssertionRelease(gSleepAssertion);
        gSleepAssertion = kIOPMNullAssertionID;
    }
    saveProConfig();
    setChargeLimit(80, nil);
}

BOOL setChargeLimit(int limit, NSError **error) {
    ensureConfigLoaded();
    if (limit < 20) limit = 20;
    if (limit > 100) limit = 100;

    gConfig.chargeLimit = limit;

    BatteryTelemetry tel = getBatteryTelemetry();
    BOOL isPluggedIn = tel.externalConnected || gConfig.isDischarging;
    if (isPluggedIn) {
        if (tel.currentCapacity > limit) {
            // Lowered slider below current percentage -> Auto Discharge to target limit
            gConfig.isDischarging = YES;
            gConfig.isTopUpActive = NO;
        } else if (tel.currentCapacity < limit) {
            // Increased slider above current percentage -> Charge up to target limit
            gConfig.isDischarging = NO;
        } else {
            // Exact match -> Hold at current percentage
            gConfig.isDischarging = NO;
        }
    }

    if (limit < 100) {
        gConfig.isTopUpActive = NO;
    }

    saveProConfig();

    BOOL helperActive = isHelperInstalledAndRunning();
    if (helperActive) {
        // 1. Direct hardware limit to SMC via privileged helper (supports 20% - 100%!)
        char limitCmd[64];
        snprintf(limitCmd, sizeof(limitCmd), "SET_LIMIT %d", limit);
        sendHelperCommand(limitCmd, NULL, 0);

        // 2. Hardware AC cut / discharge control
        char dischCmd[64];
        snprintf(dischCmd, sizeof(dischCmd), "SET_DISCHARGE %d", gConfig.isDischarging ? 1 : 0);
        sendHelperCommand(dischCmd, NULL, 0);

        // 3. MagSafe 3 LED control
        if (gConfig.isDischarging) {
            sendHelperCommand("SET_LED 2", NULL, 0); // Orange while discharging
        } else if (tel.currentCapacity == limit) {
            sendHelperCommand("SET_LED 1", NULL, 0); // Green while holding
        } else if (tel.currentCapacity < limit) {
            sendHelperCommand("SET_LED 2", NULL, 0); // Orange while charging
        } else {
            sendHelperCommand("SET_LED 0", NULL, 0); // Auto
        }
    }

    // Always keep native PowerUI in sync for limits >= 80%
    id client = getPowerUIClient();
    if (client) {
        if (limit >= 100) {
            return disableChargeLimiter(error);
        } else if (limit >= 80) {
            enableChargeLimiter(nil);
            SEL sel = NSSelectorFromString(@"setMCLLimit:error:");
            if ([client respondsToSelector:sel]) {
                BOOL ok = ((BOOL (*)(id, SEL, unsigned char, NSError **))objc_msgSend)(client, sel, (uint8_t)limit, error);
                if (ok) notifySmartChargingChanged();
                return ok;
            }
        } else {
            // Under 80%: Set PowerUI to 80% ceiling so macOS doesn't charge above 80%,
            // while our privileged helper handles the hardware discharge/hold below 80%.
            enableChargeLimiter(nil);
            SEL sel = NSSelectorFromString(@"setMCLLimit:error:");
            if ([client respondsToSelector:sel]) {
                ((BOOL (*)(id, SEL, unsigned char, NSError **))objc_msgSend)(client, sel, 80, nil);
                notifySmartChargingChanged();
            }
            if (helperActive) {
                return YES;
            } else {
                if (error) {
                    *error = [NSError errorWithDomain:@"VoltCraft" code:80 userInfo:@{
                        NSLocalizedDescriptionKey: @"Limits below 80% require the VoltCraft Privileged Helper."
                    }];
                }
                return NO;
            }
        }
    }

    return helperActive;
}

BOOL enableChargeLimiter(NSError **error) {
    id client = getPowerUIClient();
    if (!client) return NO;
    SEL sel = NSSelectorFromString(@"enableMCL:");
    if ([client respondsToSelector:sel]) {
        BOOL ok = ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(client, sel, error);
        if (ok) notifySmartChargingChanged();
        return ok;
    }
    return NO;
}

BOOL disableChargeLimiter(NSError **error) {
    if (isHelperInstalledAndRunning()) {
        sendHelperCommand("SET_LIMIT 100", NULL, 0);
        sendHelperCommand("SET_DISCHARGE 0", NULL, 0);
        sendHelperCommand("SET_LED 0", NULL, 0);
    }
    id client = getPowerUIClient();
    if (!client) return NO;
    SEL sel = NSSelectorFromString(@"disableMCL:");
    if ([client respondsToSelector:sel]) {
        BOOL ok = ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(client, sel, error);
        if (ok) notifySmartChargingChanged();
        return ok;
    }
    return NO;
}

void toggleDischarge(void) {
    ensureConfigLoaded();
    gConfig.isDischarging = !gConfig.isDischarging;
    if (gConfig.isDischarging) {
        gConfig.isTopUpActive = NO;
        if (isHelperInstalledAndRunning()) {
            sendHelperCommand("SET_DISCHARGE 1", NULL, 0);
            sendHelperCommand("SET_LED 2", NULL, 0);
        }
    } else {
        if (isHelperInstalledAndRunning()) {
            sendHelperCommand("SET_DISCHARGE 0", NULL, 0);
            BatteryTelemetry tel = getBatteryTelemetry();
            if (tel.currentCapacity >= gConfig.chargeLimit) {
                sendHelperCommand("SET_LED 1", NULL, 0);
            } else {
                sendHelperCommand("SET_LED 2", NULL, 0);
            }
        }
    }
    saveProConfig();
}

void toggleTopUp(void) {
    ensureConfigLoaded();
    gConfig.isTopUpActive = !gConfig.isTopUpActive;
    if (gConfig.isTopUpActive) {
        gConfig.isDischarging = NO;
        if (isHelperInstalledAndRunning()) {
            sendHelperCommand("SET_LIMIT 100", NULL, 0);
            sendHelperCommand("SET_DISCHARGE 0", NULL, 0);
            sendHelperCommand("SET_LED 2", NULL, 0);
        }
        id client = getPowerUIClient();
        if (client) {
            SEL sel = NSSelectorFromString(@"temporarilyOverrideMCLTargetSoC:error:");
            if ([client respondsToSelector:sel]) {
                ((BOOL (*)(id, SEL, unsigned char, NSError **))objc_msgSend)(client, sel, 100, nil);
                notifySmartChargingChanged();
                saveProConfig();
                return;
            }
        }
        disableChargeLimiter(nil);
    } else {
        setChargeLimit(gConfig.chargeLimit, nil);
    }
    saveProConfig();
}

void setSailingModeEnabled(BOOL enabled) {
    ensureConfigLoaded();
    gConfig.sailingEnabled = enabled;
    gConfig.isSailingCurrently = NO;
    saveProConfig();
}

void setSailingDifference(int diff) {
    ensureConfigLoaded();
    gConfig.sailingDifference = diff;
    saveProConfig();
}

void setHeatProtectionEnabled(BOOL enabled) {
    ensureConfigLoaded();
    gConfig.heatProtectionEnabled = enabled;
    gConfig.isHeatPaused = NO;
    saveProConfig();
}

void setMaxTemperature(float temp) {
    ensureConfigLoaded();
    gConfig.maxTemperatureC = temp;
    saveProConfig();
}

void setAllowBelow80(BOOL allow) {
    ensureConfigLoaded();
    gConfig.allowBelow80 = allow;
    saveProConfig();
}

void setStopOnSleep(BOOL stop) {
    ensureConfigLoaded();
    gConfig.stopOnSleep = stop;
    saveProConfig();
}

void setStopOnClose(BOOL stop) {
    ensureConfigLoaded();
    gConfig.stopOnClose = stop;
    saveProConfig();
}

void toggleSleepPrevent(void) {
    ensureConfigLoaded();
    gConfig.sleepPrevented = !gConfig.sleepPrevented;
    if (gConfig.sleepPrevented) {
        CFStringRef reason = CFSTR("VoltCraft Manual Sleep Control");
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep,
                                   kIOPMAssertionLevelOn,
                                   reason,
                                   &gSleepAssertion);
    } else {
        if (gSleepAssertion != kIOPMNullAssertionID) {
            IOPMAssertionRelease(gSleepAssertion);
            gSleepAssertion = kIOPMNullAssertionID;
        }
    }
    saveProConfig();
}

void startCalibration(void) {
    ensureConfigLoaded();
    gConfig.calibrationPhase = CalibrationPhaseCharge100;
    gConfig.calibrationTargetLimit = gConfig.chargeLimit;
    gConfig.calibrationHoldStartTime = 0;
    gConfig.isDischarging = NO;
    gConfig.isTopUpActive = NO;
    disableChargeLimiter(nil);
}

void stopCalibration(void) {
    ensureConfigLoaded();
    gConfig.calibrationPhase = CalibrationPhaseIdle;
    gConfig.calibrationHoldStartTime = 0;
    gConfig.isDischarging = NO;
    setChargeLimit(gConfig.chargeLimit, nil);
}

NSString *getCalibrationPhaseName(CalibrationPhase phase) {
    switch (phase) {
        case CalibrationPhaseIdle: return @"Ready to Calibrate";
        case CalibrationPhaseCharge100: return @"Phase 1/4: Charging to 100%";
        case CalibrationPhaseHold1h: return @"Phase 2/4: Holding at 100% (Equalizing)";
        case CalibrationPhaseDischarge15: return @"Phase 3/4: Discharging to 15%";
        case CalibrationPhaseRechargeTarget: return @"Phase 4/4: Recharging to Limit";
        case CalibrationPhaseComplete: return @"Calibration Complete!";
    }
}

float getCalibrationProgress(void) {
    switch (gConfig.calibrationPhase) {
        case CalibrationPhaseIdle: return 0.0f;
        case CalibrationPhaseCharge100: return 0.25f;
        case CalibrationPhaseHold1h: {
            if (gConfig.calibrationHoldStartTime <= 0) return 0.35f;
            NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - gConfig.calibrationHoldStartTime;
            float holdFrac = (float)(elapsed / 3600.0);
            return 0.25f + (MIN(holdFrac, 1.0f) * 0.25f);
        }
        case CalibrationPhaseDischarge15: return 0.65f;
        case CalibrationPhaseRechargeTarget: return 0.85f;
        case CalibrationPhaseComplete: return 1.0f;
    }
}

void getTemperatureHistory(float *outBuffer, int count) {
    int n = MIN(count, HISTORY_POINTS);
    for (int i = 0; i < n; i++) {
        int idx = (sHistoryIndex - n + i + HISTORY_POINTS) % HISTORY_POINTS;
        outBuffer[i] = sTempHistory[idx];
    }
}

void getPowerHistory(float *outBuffer, int count) {
    int n = MIN(count, HISTORY_POINTS);
    for (int i = 0; i < n; i++) {
        int idx = (sHistoryIndex - n + i + HISTORY_POINTS) % HISTORY_POINTS;
        outBuffer[i] = sPowerHistory[idx];
    }
}

void getSocHistory(float *outBuffer, int count) {
    int n = MIN(count, HISTORY_POINTS);
    for (int i = 0; i < n; i++) {
        int idx = (sHistoryIndex - n + i + HISTORY_POINTS) % HISTORY_POINTS;
        outBuffer[i] = sSocHistory[idx];
    }
}

void syncHardwareWithState(void) {
    if (!isHelperInstalledAndRunning()) return;

    BatteryTelemetry tel = getBatteryTelemetry();
    ChargeState state = getOverallChargeState();

    switch (state) {
        case ChargeStateDischarging:
            sendHelperCommand("SET_DISCHARGE 1", NULL, 0);
            sendHelperCommand("SET_LED 2", NULL, 0); // Orange
            break;
        case ChargeStateHoldingLimit:
            sendHelperCommand("SET_DISCHARGE 0", NULL, 0);
            sendHelperCommand("SET_LED 1", NULL, 0); // Green MagSafe LED
            break;
        case ChargeStateNormalCharging:
        case ChargeStateTopUp:
            sendHelperCommand("SET_DISCHARGE 0", NULL, 0);
            sendHelperCommand("SET_LED 2", NULL, 0); // Orange MagSafe LED
            break;
        case ChargeStateDisconnected:
            sendHelperCommand("SET_DISCHARGE 0", NULL, 0);
            sendHelperCommand("SET_LED 0", NULL, 0); // Auto MagSafe LED
            break;
        default:
            break;
    }
}

void runEngineCycle(void) {
    BatteryTelemetry tel = getBatteryTelemetry();

    // Record sample points in history ring buffers
    sTempHistory[sHistoryIndex] = tel.temperatureC;
    sPowerHistory[sHistoryIndex] = (float)tel.chargerWatts;
    sSocHistory[sHistoryIndex] = (float)tel.currentCapacity;
    sHistoryIndex = (sHistoryIndex + 1) % HISTORY_POINTS;

    // 1. Heat Protection Engine
    if (gConfig.heatProtectionEnabled && tel.temperatureC > 0.0f) {
        if (!gConfig.isHeatPaused && tel.temperatureC >= gConfig.maxTemperatureC) {
            gConfig.isHeatPaused = YES;
            enableChargeLimiter(nil);
            setChargeLimit(MAX(20, tel.currentCapacity - 5), nil);
        } else if (gConfig.isHeatPaused && tel.temperatureC <= (gConfig.maxTemperatureC - 2.0f)) {
            gConfig.isHeatPaused = NO;
            setChargeLimit(gConfig.chargeLimit, nil);
        }
    }

    // 2. Calibration State Machine
    if (gConfig.calibrationPhase != CalibrationPhaseIdle) {
        switch (gConfig.calibrationPhase) {
            case CalibrationPhaseCharge100:
                if (tel.currentCapacity >= 100) {
                    gConfig.calibrationPhase = CalibrationPhaseHold1h;
                    gConfig.calibrationHoldStartTime = [NSDate timeIntervalSinceReferenceDate];
                }
                break;
            case CalibrationPhaseHold1h: {
                NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - gConfig.calibrationHoldStartTime;
                if (elapsed >= 3600.0) {
                    gConfig.calibrationPhase = CalibrationPhaseDischarge15;
                    gConfig.isDischarging = YES;
                    setChargeLimit(15, nil);
                }
                break;
            }
            case CalibrationPhaseDischarge15:
                if (tel.currentCapacity <= 15) {
                    gConfig.isDischarging = NO;
                    gConfig.calibrationPhase = CalibrationPhaseRechargeTarget;
                    setChargeLimit(gConfig.calibrationTargetLimit, nil);
                }
                break;
            case CalibrationPhaseRechargeTarget:
                if (tel.currentCapacity >= gConfig.calibrationTargetLimit) {
                    gConfig.calibrationPhase = CalibrationPhaseComplete;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (gConfig.calibrationPhase == CalibrationPhaseComplete) {
                            gConfig.calibrationPhase = CalibrationPhaseIdle;
                        }
                    });
                }
                break;
            default:
                break;
        }
        return;
    }

    // 3. Discharge Mode & Dynamic Target Monitoring
    if (gConfig.isDischarging) {
        if (tel.currentCapacity <= gConfig.chargeLimit) {
            // Reached target limit! Stop discharge and hold at limit
            gConfig.isDischarging = NO;
            saveProConfig();
            setChargeLimit(gConfig.chargeLimit, nil);
            if (isHelperInstalledAndRunning()) {
                sendHelperCommand("SET_DISCHARGE 0", NULL, 0);
                sendHelperCommand("SET_LED 1", NULL, 0); // Green holding LED
            }
        }
    } else if (tel.externalConnected && !gConfig.sailingEnabled && !gConfig.isTopUpActive && !gConfig.isHeatPaused) {
        if (tel.currentCapacity > gConfig.chargeLimit) {
            // Battery is higher than set limit -> Engage discharge down to target
            gConfig.isDischarging = YES;
            saveProConfig();
            if (isHelperInstalledAndRunning()) {
                sendHelperCommand("SET_DISCHARGE 1", NULL, 0);
                sendHelperCommand("SET_LED 2", NULL, 0); // Orange while discharging
            }
        }
    }

    // 4. Sailing Mode Engine
    if (gConfig.sailingEnabled && !gConfig.isTopUpActive && !gConfig.isHeatPaused) {
        int target = gConfig.chargeLimit;
        int floor = MAX(20, target - gConfig.sailingDifference);

        if (!gConfig.isSailingCurrently && tel.currentCapacity >= target) {
            gConfig.isSailingCurrently = YES;
            setChargeLimit(floor, nil);
        } else if (gConfig.isSailingCurrently && tel.currentCapacity <= floor) {
            gConfig.isSailingCurrently = NO;
            setChargeLimit(target, nil);
        }
    }

    // Synchronize hardware helper state
    syncHardwareWithState();
}

ChargeState getOverallChargeState(void) {
    BatteryTelemetry tel = getBatteryTelemetry();

    // Forced discharge overrides external connection check (because CHIE=1 cuts AC sink)
    if (gConfig.isDischarging) {
        return ChargeStateDischarging;
    }

    if (!tel.externalConnected) return ChargeStateDisconnected;
    if (gConfig.calibrationPhase != CalibrationPhaseIdle) return ChargeStateCalibration;
    if (gConfig.isHeatPaused) return ChargeStateHeatPaused;
    if (gConfig.isTopUpActive) return ChargeStateTopUp;

    // Explicit catch-up logic:
    // 1. Lowered below current battery -> Auto Discharge
    if (tel.currentCapacity > gConfig.chargeLimit) {
        return ChargeStateDischarging;
    }

    // 2. Sailing mode drop underway
    if (gConfig.sailingEnabled && gConfig.isSailingCurrently) {
        return ChargeStateSailing;
    }

    // 3. Raised above current battery -> Charge up to target
    if (tel.currentCapacity < gConfig.chargeLimit) {
        return ChargeStateNormalCharging;
    }

    // 4. Exact match -> Hold at current percentage
    return ChargeStateHoldingLimit;
}

NSString *getChargeStateDescription(ChargeState state) {
    switch (state) {
        case ChargeStateDisconnected: return @"On Battery";
        case ChargeStateNormalCharging: return [NSString stringWithFormat:@"Charging to %d%%", gConfig.chargeLimit];
        case ChargeStateHoldingLimit: return [NSString stringWithFormat:@"Holding at %d%%", gConfig.chargeLimit];
        case ChargeStateSailing: return [NSString stringWithFormat:@"Sailing (Drop to %d%%)", MAX(20, gConfig.chargeLimit - gConfig.sailingDifference)];
        case ChargeStateDischarging: return [NSString stringWithFormat:@"Discharging to %d%%", gConfig.chargeLimit];
        case ChargeStateHeatPaused: return @"Paused (Heat Protection)";
        case ChargeStateTopUp: return @"Top Up Active (100%)";
        case ChargeStateCalibration: return getCalibrationPhaseName(gConfig.calibrationPhase);
    }
}

BatteryTelemetry getBatteryTelemetry(void) {
    BatteryTelemetry tel;
    memset(&tel, 0, sizeof(tel));
    strncpy(tel.chargerName, "Disconnected", sizeof(tel.chargerName) - 1);
    tel.chargeLimit = gConfig.chargeLimit;
    tel.temperatureC = readBatteryTemperatureFromSMC();

    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"));
    if (!service) return tel;

    CFMutableDictionaryRef propRef = NULL;
    if (IORegistryEntryCreateCFProperties(service, &propRef, kCFAllocatorDefault, 0) == kIOReturnSuccess && propRef) {
        NSDictionary *props = CFBridgingRelease(propRef);

        tel.currentCapacity = [props[@"CurrentCapacity"] intValue];
        tel.maxCapacity = [props[@"MaxCapacity"] intValue];
        tel.cycleCount = [props[@"CycleCount"] intValue];
        
        BOOL extConn = [props[@"ExternalConnected"] boolValue];
        if (!extConn) {
            NSArray *fed = props[@"FedDetails"];
            if ([fed isKindOfClass:[NSArray class]]) {
                for (NSDictionary *d in fed) {
                    if ([d isKindOfClass:[NSDictionary class]] && [d[@"FedExternalConnected"] boolValue]) {
                        extConn = YES;
                        break;
                    }
                }
            }
        }
        tel.externalConnected = extConn;

        tel.voltageMv = [props[@"Voltage"] intValue];
        tel.amperageMa = [props[@"Amperage"] intValue];

        NSDictionary *chargerData = props[@"ChargerData"];
        if (chargerData) {
            tel.isCharging = [chargerData[@"IsCharging"] boolValue];
        }

        NSDictionary *battData = props[@"BatteryData"];
        if (battData) {
            tel.rawCurrentCapacity = [battData[@"AppleRawCurrentCapacity"] intValue];
            tel.rawMaxCapacity = [battData[@"AppleRawMaxCapacity"] intValue];
            tel.designCapacity = [battData[@"DesignCapacity"] intValue];
            tel.fullyCharged = [battData[@"FullyCharged"] boolValue];

            if (tel.designCapacity > 0) {
                tel.healthPercentage = ((double)tel.rawMaxCapacity / (double)tel.designCapacity) * 100.0;
            }
        }

        NSDictionary *adapter = props[@"AdapterDetails"];
        if (adapter) {
            tel.chargerWatts = [adapter[@"Watts"] intValue];
            NSString *name = adapter[@"Name"] ?: adapter[@"Description"];
            if (name) {
                strncpy(tel.chargerName, [name UTF8String], sizeof(tel.chargerName) - 1);
            }
        }
    }
    IOObjectRelease(service);
    return tel;
}
