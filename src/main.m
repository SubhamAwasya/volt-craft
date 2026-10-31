#import <Cocoa/Cocoa.h>
#import "battery_core.h"
#import "menu_bar.h"

static void printUsage(const char *prog) {
    printf("VoltCraft Pro - Ultra-Lightweight macOS Battery & Charge Controller\n");
    printf("Usage: %s [command] [options]\n\n", prog);
    printf("Commands:\n");
    printf("  (none) / app                Launch the full VoltCraft Pro Dashboard Window & Menu Bar\n");
    printf("  status                      Display current status, pro features, and telemetry\n");
    printf("  limit <pct>                 Set charge limit (20 - 100)\n");
    printf("  topup                       Toggle Top-Up (100%% charge override)\n");
    printf("  discharge                   Toggle forced battery discharge\n");
    printf("  sailing [on|off] [delta]    Configure Sailing Mode (delta 1-15%%)\n");
    printf("  heat [on|off] [maxTemp]     Configure Heat Protection (e.g. 35.0 C)\n");
    printf("  calibrate [start|stop]      Start or stop battery calibration cycle\n");
    printf("  sleep                       Toggle manual sleep prevention\n");
    printf("  help                        Show this help information\n\n");
    printf("Examples:\n");
    printf("  %s status\n", prog);
    printf("  %s limit 80\n", prog);
    printf("  %s sailing on 5\n", prog);
    printf("  %s heat on 35.0\n", prog);
    printf("  %s app\n", prog);
}

static void printStatus(void) {
    loadProConfig();
    BatteryTelemetry tel = getBatteryTelemetry();
    VoltCraftConfig *cfg = getProConfig();
    ChargeState state = getOverallChargeState();

    printf("\n");
    printf("============================================================\n");
    printf("                 VoltCraft Pro — System Status              \n");
    printf("============================================================\n");
    printf("Battery Level:         %d%%\n", tel.currentCapacity);
    printf("Power State:           %s\n", [getChargeStateDescription(state) UTF8String]);
    printf("Configured Limit:      %d%%\n", cfg->chargeLimit);
    printf("Top-Up Mode:           %s\n", cfg->isTopUpActive ? "ACTIVE (100%)" : "Off");
    printf("Forced Discharge:      %s\n", cfg->isDischarging ? "ACTIVE" : "Off");
    printf("Sleep Prevented:       %s\n", cfg->sleepPrevented ? "YES (Mac Kept Awake)" : "No");

    printf("\n--- Pro Protection Engines ---\n");
    printf("Sailing Mode:          %s\n", cfg->sailingEnabled ? "ENABLED" : "Disabled");
    if (cfg->sailingEnabled) {
        printf("  • Sailing Delta:     %d%% (Sails down to %d%%)\n", cfg->sailingDifference, MAX(20, cfg->chargeLimit - cfg->sailingDifference));
        printf("  • Current Phase:     %s\n", cfg->isSailingCurrently ? "Sailing (Drop phase)" : "Recharging to Limit");
    }

    printf("Heat Protection:       %s\n", cfg->heatProtectionEnabled ? "ENABLED" : "Disabled");
    if (cfg->heatProtectionEnabled) {
        printf("  • Max Temp Cutoff:   %.1f °C\n", cfg->maxTemperatureC);
        printf("  • Live SMC Sensor:   %.1f °C (%s)\n", tel.temperatureC, cfg->isHeatPaused ? "PAUSED (Too Hot!)" : "Safe");
    }

    printf("Calibration Mode:      %s\n", (cfg->calibrationPhase == CalibrationPhaseIdle) ? "IDLE" : [getCalibrationPhaseName(cfg->calibrationPhase) UTF8String]);

    printf("\n--- Battery Health & Diagnostics ---\n");
    printf("State of Health (SoH): %.1f%% (%d / %d mAh)\n", tel.healthPercentage, tel.rawMaxCapacity, tel.designCapacity);
    printf("Cycle Count:           %d cycles\n", tel.cycleCount);
    printf("Battery Voltage:       %.2f V\n", tel.voltageMv / 1000.0);
    printf("Instant Amperage:      %d mA\n", tel.amperageMa);
    if (tel.externalConnected) {
        printf("Power Supply:          %dW (%s)\n", tel.chargerWatts, tel.chargerName);
    } else {
        printf("Power Supply:          Disconnected (Running on Battery)\n");
    }
    printf("============================================================\n\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        loadProConfig();

        if (argc > 1) {
            NSString *arg = [NSString stringWithUTF8String:argv[1]];

            if ([arg isEqualToString:@"status"] || [arg isEqualToString:@"-s"]) {
                printStatus();
                return 0;
            } else if ([arg isEqualToString:@"limit"] || [arg isEqualToString:@"-l"]) {
                if (argc < 3) {
                    fprintf(stderr, "Error: missing limit percentage (20 - 100)\n");
                    return 1;
                }
                int limit = atoi(argv[2]);
                if (limit < 20 || limit > 100) {
                    fprintf(stderr, "Error: limit %d out of range (20 - 100)\n", limit);
                    return 1;
                }
                NSError *error = nil;
                if (setChargeLimit(limit, &error)) {
                    printf("VoltCraft Pro: Successfully set charge limit to %d%%!\n", limit);
                    return 0;
                } else {
                    fprintf(stderr, "Error: %s\n", error ? [[error description] UTF8String] : "failed");
                    return 1;
                }
            } else if ([arg isEqualToString:@"topup"] || [arg isEqualToString:@"-t"]) {
                toggleTopUp();
                VoltCraftConfig *cfg = getProConfig();
                printf("Top-Up mode: %s\n", cfg->isTopUpActive ? "ACTIVATED (Charging to 100%)" : "DEACTIVATED");
                return 0;
            } else if ([arg isEqualToString:@"discharge"] || [arg isEqualToString:@"-d"]) {
                toggleDischarge();
                VoltCraftConfig *cfg = getProConfig();
                printf("Discharge mode: %s\n", cfg->isDischarging ? "ACTIVATED" : "DEACTIVATED");
                return 0;
            } else if ([arg isEqualToString:@"sailing"]) {
                if (argc >= 3) {
                    NSString *sub = [NSString stringWithUTF8String:argv[2]];
                    BOOL en = [sub isEqualToString:@"on"] || [sub isEqualToString:@"1"] || [sub isEqualToString:@"true"];
                    setSailingModeEnabled(en);
                    if (argc >= 4) {
                        setSailingDifference(atoi(argv[3]));
                    }
                }
                VoltCraftConfig *cfg = getProConfig();
                printf("Sailing Mode: %s (Delta: %d%%)\n", cfg->sailingEnabled ? "ENABLED" : "DISABLED", cfg->sailingDifference);
                return 0;
            } else if ([arg isEqualToString:@"heat"]) {
                if (argc >= 3) {
                    NSString *sub = [NSString stringWithUTF8String:argv[2]];
                    BOOL en = [sub isEqualToString:@"on"] || [sub isEqualToString:@"1"] || [sub isEqualToString:@"true"];
                    setHeatProtectionEnabled(en);
                    if (argc >= 4) {
                        setMaxTemperature(atof(argv[3]));
                    }
                }
                VoltCraftConfig *cfg = getProConfig();
                printf("Heat Protection: %s (Max Temp: %.1f °C)\n", cfg->heatProtectionEnabled ? "ENABLED" : "DISABLED", cfg->maxTemperatureC);
                return 0;
            } else if ([arg isEqualToString:@"sleep"]) {
                toggleSleepPrevent();
                VoltCraftConfig *cfg = getProConfig();
                printf("Manual Sleep Control: %s\n", cfg->sleepPrevented ? "PREVENT SLEEP (Active)" : "ALLOW SLEEP (Normal)");
                return 0;
            } else if ([arg isEqualToString:@"calibrate"]) {
                if (argc >= 3) {
                    NSString *sub = [NSString stringWithUTF8String:argv[2]];
                    if ([sub isEqualToString:@"start"]) startCalibration();
                    else if ([sub isEqualToString:@"stop"]) stopCalibration();
                }
                VoltCraftConfig *cfg = getProConfig();
                printf("Calibration: %s\n", [getCalibrationPhaseName(cfg->calibrationPhase) UTF8String]);
                return 0;
            } else if ([arg isEqualToString:@"help"] || [arg isEqualToString:@"-h"] || [arg isEqualToString:@"--help"]) {
                printUsage(argv[0]);
                return 0;
            } else if ([arg isEqualToString:@"app"] || [arg isEqualToString:@"gui"]) {
                // Launch GUI
            } else {
                fprintf(stderr, "Unknown command: %s\n", argv[1]);
                printUsage(argv[0]);
                return 1;
            }
        }

        // GUI Application Mode (Menu Bar / Accessory Agent — No Dock Icon)
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

        VoltCraftAppDelegate *delegate = [[VoltCraftAppDelegate alloc] init];
        [NSApp setDelegate:delegate];
        [NSApp run];
    }
    return 0;
}
