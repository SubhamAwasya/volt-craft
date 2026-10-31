#ifndef BATTERY_CORE_H
#define BATTERY_CORE_H

#import <Foundation/Foundation.h>

// Calibration Phases
typedef NS_ENUM(NSInteger, CalibrationPhase) {
    CalibrationPhaseIdle = 0,
    CalibrationPhaseCharge100,      // Phase 1: Charge to 100%
    CalibrationPhaseHold1h,         // Phase 2: Hold at 100% for 60 min
    CalibrationPhaseDischarge15,    // Phase 3: Discharge to 15%
    CalibrationPhaseRechargeTarget, // Phase 4: Recharge back to user limit
    CalibrationPhaseComplete        // Phase 5: Complete
};

// Overall Charging Engine State
typedef NS_ENUM(NSInteger, ChargeState) {
    ChargeStateNormalCharging = 0,
    ChargeStateHoldingLimit,
    ChargeStateSailing,
    ChargeStateDischarging,
    ChargeStateHeatPaused,
    ChargeStateTopUp,
    ChargeStateCalibration,
    ChargeStateDisconnected
};

typedef struct {
    int currentCapacity;       // Battery percentage (0-100)
    int maxCapacity;           // Max capacity percentage (100)
    int rawCurrentCapacity;    // Current capacity in mAh
    int rawMaxCapacity;        // Max capacity in mAh
    int designCapacity;        // Original design capacity in mAh
    int cycleCount;            // Battery charge cycle count
    double healthPercentage;   // Health % (rawMaxCapacity / designCapacity)
    int voltageMv;             // Battery voltage in mV
    int amperageMa;            // Current flow in mA
    float temperatureC;        // Temperature in Celsius from SMC
    BOOL externalConnected;    // True if AC adapter connected
    BOOL isCharging;           // True if currently charging
    BOOL fullyCharged;         // True if at 100%
    int chargerWatts;          // AC charger wattage (e.g. 30W, 70W, 140W)
    char chargerName[64];      // Charger description
    int chargeLimit;           // Configured charge limit (e.g. 20 - 100)
    BOOL mclEnabled;           // Manual Charge Limit active
} BatteryTelemetry;

// Pro Settings & State Structure
typedef struct {
    int chargeLimit;                // Set limit (e.g. 80)
    BOOL allowBelow80;              // Allow limit < 80% (20% - 100%)
    BOOL isDischarging;             // User activated forced discharge
    BOOL isTopUpActive;             // User activated Top-Up (100% charge once)
    
    // Sailing Mode
    BOOL sailingEnabled;            // Sailing mode active
    int sailingDifference;          // Drop delta (e.g. 5%, drops 80% -> 75%)
    BOOL isSailingCurrently;        // Currently in sail drop phase
    
    // Heat Protection
    BOOL heatProtectionEnabled;     // Heat protection active
    float maxTemperatureC;         // Threshold (e.g. 35.0 °C)
    BOOL isHeatPaused;              // Currently paused due to heat
    
    // Sleep & Power Controls
    BOOL stopOnSleep;               // Stop charging when Mac sleeps
    BOOL stopOnClose;               // Stop charging when app exits
    BOOL sleepPrevented;            // Manual Sleep Control (Prevent Sleep)
    
    // Calibration Mode
    CalibrationPhase calibrationPhase;
    NSTimeInterval calibrationHoldStartTime;
    int calibrationTargetLimit;
    
    // General
    BOOL launchAtLogin;
} VoltCraftConfig;

#ifdef __cplusplus
extern "C" {
#endif

// Telemetry & Hardware
BatteryTelemetry getBatteryTelemetry(void);
float readBatteryTemperatureFromSMC(void);
ChargeState getOverallChargeState(void);
NSString *getChargeStateDescription(ChargeState state);

// Config Management
VoltCraftConfig *getProConfig(void);
void loadProConfig(void);
void saveProConfig(void);
void resetProConfig(void);

// Charge Limit Control
BOOL setChargeLimit(int limit, NSError **error);
BOOL enableChargeLimiter(NSError **error);
BOOL disableChargeLimiter(NSError **error);

// Pro Feature Actions
void toggleDischarge(void);
void toggleTopUp(void);
void setSailingModeEnabled(BOOL enabled);
void setSailingDifference(int diff);
void setHeatProtectionEnabled(BOOL enabled);
void setMaxTemperature(float temp);
void setAllowBelow80(BOOL allow);
void setStopOnSleep(BOOL stop);
void setStopOnClose(BOOL stop);
void toggleSleepPrevent(void);

// Calibration Actions
void startCalibration(void);
void stopCalibration(void);
NSString *getCalibrationPhaseName(CalibrationPhase phase);
float getCalibrationProgress(void);

// Privileged Helper Communication
BOOL isHelperInstalledAndRunning(void);
BOOL sendHelperCommand(const char *cmd, char *outResp, size_t maxLen);
void syncHardwareWithState(void);

// Telemetry History for Charts (20 sample points)
void getTemperatureHistory(float *outBuffer, int count);
void getPowerHistory(float *outBuffer, int count);
void getSocHistory(float *outBuffer, int count);

// Background Engine Tick (called every 2 seconds)
void runEngineCycle(void);

#ifdef __cplusplus
}
#endif

#endif // BATTERY_CORE_H
