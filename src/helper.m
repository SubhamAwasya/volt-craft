#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>

#define SOCKET_PATH "/var/run/voltcraft_helper.sock"

#define KERNEL_INDEX_SMC     2
#define SMC_CMD_READ_BYTES   5
#define SMC_CMD_WRITE_BYTES  6
#define SMC_CMD_READ_KEYINFO 9

// Standard 80-byte Apple SMC Param Struct
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

static io_connect_t gSMCConnection = 0;
static pthread_mutex_t gSMCLock = PTHREAD_MUTEX_INITIALIZER;

static uint32_t strToKey(const char *str) {
    uint32_t key = 0;
    for (int i = 0; i < 4 && str[i]; i++) {
        key = (key << 8) | ((uint8_t)str[i]);
    }
    return key;
}

static BOOL openSMC(void) {
    if (gSMCConnection != 0) return YES;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) {
        NSLog(@"[VoltCraftHelper] Error: AppleSMC service not found");
        return NO;
    }
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &gSMCConnection);
    IOObjectRelease(service);
    if (kr != kIOReturnSuccess || gSMCConnection == 0) {
        NSLog(@"[VoltCraftHelper] Error: IOServiceOpen AppleSMC failed (0x%08x)", kr);
        return NO;
    }
    NSLog(@"[VoltCraftHelper] Successfully connected to AppleSMC (connection = %d)", gSMCConnection);
    return YES;
}

static BOOL readSMCKey(const char *keyStr, uint8_t *outBytes, uint32_t *outSize) {
    pthread_mutex_lock(&gSMCLock);
    if (!openSMC()) {
        pthread_mutex_unlock(&gSMCLock);
        return NO;
    }

    SMCParamStruct input;
    SMCParamStruct output;
    size_t outputSize = sizeof(output);

    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = strToKey(keyStr);
    input.data8 = SMC_CMD_READ_KEYINFO;

    kern_return_t kr = IOConnectCallStructMethod(gSMCConnection, KERNEL_INDEX_SMC, &input, sizeof(input), &output, &outputSize);
    if (kr != kIOReturnSuccess || output.result != 0) {
        pthread_mutex_unlock(&gSMCLock);
        return NO;
    }

    uint32_t dataSize = output.keyInfo.dataSize;
    if (dataSize > 32) dataSize = 32;

    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = strToKey(keyStr);
    input.keyInfo.dataSize = dataSize;
    input.data8 = SMC_CMD_READ_BYTES;

    kr = IOConnectCallStructMethod(gSMCConnection, KERNEL_INDEX_SMC, &input, sizeof(input), &output, &outputSize);
    pthread_mutex_unlock(&gSMCLock);

    if (kr != kIOReturnSuccess || output.result != 0) {
        return NO;
    }

    if (outSize) *outSize = dataSize;
    if (outBytes) memcpy(outBytes, output.bytes, dataSize);
    return YES;
}

static BOOL writeSMCByte(const char *keyStr, uint8_t val) {
    pthread_mutex_lock(&gSMCLock);
    if (!openSMC()) {
        pthread_mutex_unlock(&gSMCLock);
        return NO;
    }

    SMCParamStruct input;
    SMCParamStruct output;
    size_t outputSize = sizeof(output);

    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = strToKey(keyStr);
    input.data8 = SMC_CMD_READ_KEYINFO;

    kern_return_t kr = IOConnectCallStructMethod(gSMCConnection, KERNEL_INDEX_SMC, &input, sizeof(input), &output, &outputSize);
    if (kr != kIOReturnSuccess || output.result != 0) {
        pthread_mutex_unlock(&gSMCLock);
        return NO;
    }

    uint32_t dataSize = output.keyInfo.dataSize;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = strToKey(keyStr);
    input.keyInfo.dataSize = (dataSize > 0) ? dataSize : 1;
    input.data8 = SMC_CMD_WRITE_BYTES;
    input.bytes[0] = val;

    kr = IOConnectCallStructMethod(gSMCConnection, KERNEL_INDEX_SMC, &input, sizeof(input), &output, &outputSize);
    pthread_mutex_unlock(&gSMCLock);

    BOOL success = (kr == kIOReturnSuccess && output.result == 0);
    if (!success) {
        NSLog(@"[VoltCraftHelper] writeSMCByte '%s' = 0x%02x failed: kr=0x%08x, result=%d", keyStr, val, kr, output.result);
    }
    return success;
}

// Active State
static int gTargetLimit = 80;
static BOOL gDischarging = NO;
static int gMagSafeLEDMode = 0; // 0=Auto, 1=Green, 2=Orange, 3=Off, 4=Blink Orange

static int getCurrentBatteryPercent(void);

static void applyHardwareSettings(void) {
    NSLog(@"[VoltCraftHelper] Applying settings: Limit=%d, Discharging=%d, LED=%d",
          gTargetLimit, gDischarging, gMagSafeLEDMode);

    int cur = getCurrentBatteryPercent();

    if (gDischarging) {
        // MagSafe 3 LED control:
        // SMC register 'ACLC': 0x00=Auto, 0x01=Off, 0x03=Solid Green, 0x04=Solid Orange, 0x06=Blink Orange
        uint8_t ledVal = 0x04; // Solid Orange while discharging
        if (gMagSafeLEDMode == 1) ledVal = 0x03; // Green
        else if (gMagSafeLEDMode == 2) ledVal = 0x04; // Orange
        else if (gMagSafeLEDMode == 3) ledVal = 0x01; // Off
        else if (gMagSafeLEDMode == 4) ledVal = 0x06; // Blink Orange

        // Set MagSafe cable LED color
        writeSMCByte("ACLC", ledVal);

        // Cut AC sink to force discharge (Universal Apple Silicon M1/M2/M3/M4 + Intel)
        writeSMCByte("CHIE", 0x01); // Apple Silicon M2/M3/M4 Charger Inhibit External
        writeSMCByte("CH0B", 0x02); // Intel/M1 Charge Inhibit
        writeSMCByte("CH0C", 0x02);
        writeSMCByte("CH0I", 0x01);

        // Re-affirm LED after inhibit
        writeSMCByte("ACLC", ledVal);
    } else {
        // Clear discharge inhibit (0x00 = AC power connected & sinking)
        writeSMCByte("CHIE", 0x00);
        writeSMCByte("CH0B", 0x00);
        writeSMCByte("CH0C", 0x00);
        writeSMCByte("CH0I", 0x00);

        // MagSafe LED
        BOOL isHoldingLimit = (cur > 0 && cur >= gTargetLimit);
        uint8_t ledVal = 0x00; // Auto
        if (gMagSafeLEDMode == 1 || (gMagSafeLEDMode == 0 && isHoldingLimit)) {
            ledVal = 0x03; // Solid Green when holding limit!
        } else if (gMagSafeLEDMode == 2 || (gMagSafeLEDMode == 0 && !isHoldingLimit && gTargetLimit < 100)) {
            ledVal = 0x04; // Solid Orange while charging
        } else if (gMagSafeLEDMode == 3) {
            ledVal = 0x01; // Off
        } else if (gMagSafeLEDMode == 4) {
            ledVal = 0x06; // Blink Orange
        } else {
            ledVal = 0x00; // Auto
        }
        writeSMCByte("ACLC", ledVal);
    }
}

static int getCurrentBatteryPercent(void) {
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (!info) return -1;
    CFArrayRef list = IOPSCopyPowerSourcesList(info);
    if (!list) {
        CFRelease(info);
        return -1;
    }
    int percent = -1;
    CFIndex count = CFArrayGetCount(list);
    for (CFIndex i = 0; i < count; i++) {
        CFTypeRef source = CFArrayGetValueAtIndex(list, i);
        CFDictionaryRef desc = IOPSGetPowerSourceDescription(info, source);
        if (desc) {
            CFNumberRef curCap = CFDictionaryGetValue(desc, CFSTR(kIOPSCurrentCapacityKey));
            if (curCap) {
                CFNumberGetValue(curCap, kCFNumberIntType, &percent);
                break;
            }
        }
    }
    CFRelease(list);
    CFRelease(info);
    return percent;
}

// Background Monitor: automatically stops discharge when target limit is reached
static void *batteryMonitorLoop(void *arg) {
    (void)arg;
    while (1) {
        sleep(2);
        if (gDischarging) {
            int cur = getCurrentBatteryPercent();
            if (cur > 0 && cur <= gTargetLimit) {
                NSLog(@"[VoltCraftHelper] Battery reached target %d%% (current %d%%). Halting forced discharge.",
                      gTargetLimit, cur);
                gDischarging = NO;
                // Switch MagSafe LED to Green (holding limit)
                gMagSafeLEDMode = 1;
                applyHardwareSettings();
            }
        }
    }
    return NULL;
}

static void handleClientCommand(int clientFd, const char *cmd) {
    char response[512] = "OK\n";

    if (strncmp(cmd, "PING", 4) == 0) {
        snprintf(response, sizeof(response), "PONG VoltCraftHelper 1.0\n");
    } else if (strncmp(cmd, "SET_LIMIT ", 10) == 0) {
        int limit = atoi(cmd + 10);
        if (limit >= 20 && limit <= 100) {
            gTargetLimit = limit;
            int cur = getCurrentBatteryPercent();
            if (cur > limit) {
                // Auto discharge if current capacity exceeds newly set limit
                gDischarging = YES;
            } else {
                gDischarging = NO;
            }
            applyHardwareSettings();
            snprintf(response, sizeof(response), "OK LIMIT=%d DISCHARGE=%d\n", limit, gDischarging);
        } else {
            snprintf(response, sizeof(response), "ERR INVALID_LIMIT\n");
        }
    } else if (strncmp(cmd, "SET_DISCHARGE ", 14) == 0) {
        int discharge = atoi(cmd + 14);
        gDischarging = (discharge != 0);
        applyHardwareSettings();
        snprintf(response, sizeof(response), "OK DISCHARGE=%d\n", gDischarging);
    } else if (strncmp(cmd, "SET_LED ", 8) == 0) {
        int mode = atoi(cmd + 8);
        gMagSafeLEDMode = mode;
        applyHardwareSettings();
        snprintf(response, sizeof(response), "OK LED=%d\n", mode);
    } else if (strncmp(cmd, "WRITE_SMC ", 10) == 0) {
        char keyStr[8] = {0};
        unsigned int val = 0;
        if (sscanf(cmd + 10, "%4s %x", keyStr, &val) == 2) {
            BOOL ok = writeSMCByte(keyStr, (uint8_t)val);
            snprintf(response, sizeof(response), ok ? "OK WRITE %s=0x%02x\n" : "ERR WRITE_FAILED\n", keyStr, val);
        } else {
            snprintf(response, sizeof(response), "ERR BAD_ARGS\n");
        }
    } else if (strncmp(cmd, "READ_SMC ", 9) == 0) {
        char keyStr[8] = {0};
        if (sscanf(cmd + 9, "%4s", keyStr) == 1) {
            uint8_t val = 0;
            uint32_t sz = 0;
            BOOL ok = readSMCKey(keyStr, &val, &sz);
            snprintf(response, sizeof(response), ok ? "OK READ %s=0x%02x\n" : "ERR READ_FAILED\n", keyStr, val);
        } else {
            snprintf(response, sizeof(response), "ERR BAD_ARGS\n");
        }
    } else if (strncmp(cmd, "STOP_ALL", 8) == 0) {
        gDischarging = NO;
        gTargetLimit = 100;
        gMagSafeLEDMode = 0;
        applyHardwareSettings();
        snprintf(response, sizeof(response), "OK STOPPED\n");
    } else if (strncmp(cmd, "GET_STATUS", 10) == 0) {
        uint8_t chie = 0, aclc = 0, bclm = 0;
        readSMCKey("CHIE", &chie, NULL);
        readSMCKey("ACLC", &aclc, NULL);
        readSMCKey("BCLM", &bclm, NULL);
        int cur = getCurrentBatteryPercent();
        snprintf(response, sizeof(response),
                 "OK STATUS limit=%d discharge=%d led=%d chie=0x%02x aclc=0x%02x bclm=%u cur=%d\n",
                 gTargetLimit, gDischarging, gMagSafeLEDMode, chie, aclc, bclm, cur);
    } else {
        snprintf(response, sizeof(response), "ERR UNKNOWN_COMMAND\n");
    }

    write(clientFd, response, strlen(response));
}

int main(int argc, char *argv[]) {
    signal(SIGPIPE, SIG_IGN);

    unlink(SOCKET_PATH);

    int serverFd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (serverFd < 0) {
        perror("socket");
        return 1;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (bind(serverFd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        return 1;
    }

    // Allow user processes to communicate with root helper
    chmod(SOCKET_PATH, 0666);

    if (listen(serverFd, 10) < 0) {
        perror("listen");
        return 1;
    }

    NSLog(@"[VoltCraftHelper] Privileged Daemon running on %s (euid=%d)", SOCKET_PATH, geteuid());
    openSMC();
    applyHardwareSettings();

    // Start background monitor thread
    pthread_t monitorThread;
    pthread_create(&monitorThread, NULL, batteryMonitorLoop, NULL);
    pthread_detach(monitorThread);

    while (1) {
        int clientFd = accept(serverFd, NULL, NULL);
        if (clientFd < 0) continue;

        char buf[512] = {0};
        ssize_t bytesRead = read(clientFd, buf, sizeof(buf) - 1);
        if (bytesRead > 0) {
            while (bytesRead > 0 && (buf[bytesRead - 1] == '\n' || buf[bytesRead - 1] == '\r')) {
                buf[--bytesRead] = '\0';
            }
            handleClientCommand(clientFd, buf);
        }
        close(clientFd);
    }

    if (gSMCConnection) IOServiceClose(gSMCConnection);
    unlink(SOCKET_PATH);
    return 0;
}
