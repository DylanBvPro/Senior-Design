#pragma once
#include <vector>
#include <string>
#include "GameTypes.h"

// Forward declarations (or include a shared header if you make one later)
struct UserInteractionInput;
struct RunScores;

enum RunMode {
    RUN_MODE_CANCEL = 0,
    RUN_MODE_MANUAL = 1,
    RUN_MODE_AUTO = 2,
    RUN_MODE_RESET = 3
};

enum DifficultyMode {
    DIFFICULTY_CANCEL = 0,
    DIFFICULTY_EASY = 1,
    DIFFICULTY_HARD = 2
};

enum AutoRunProfile {
    AUTO_PROFILE_CANCEL = 0,
    AUTO_PROFILE_SCENARIO_1 = 1,
    AUTO_PROFILE_SCENARIO_2 = 2,
    AUTO_PROFILE_SCENARIO_3 = 3,
    AUTO_PROFILE_SCENARIO_4 = 4,
    AUTO_PROFILE_RANDOM = 5,
    AUTO_PROFILE_OVERPOWERED = 6
};

// Public API
DifficultyMode promptDifficultyModePopup();
RunMode promptRunModePopup();
AutoRunProfile promptAutoRunProfilePopup(int& gamesToRun);
bool confirmResetTrainingDataPopup();

bool showInteractionInputPopup(
    UserInteractionInput& output,
    bool askDeathChoice,
    bool manualMode = false,
    double lockedHealth = 0.0
);

void showAutoRunSummaryWindow(const std::string& summaryText);