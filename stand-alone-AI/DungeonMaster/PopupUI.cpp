#include "PopupUI.h"
#include "GameTypes.h"

#include <iostream>
#include <sstream>
#include <iomanip>

#ifdef _WIN32
#include <windows.h>
#include <array>

// ============================================================
// INTERNAL STRUCTS / IDS (PRIVATE)
// ============================================================

enum PopupControlId {
    CTRL_EDIT_TIME = 1001,
    CTRL_EDIT_PHYSICAL,
    CTRL_EDIT_MAGIC,
    CTRL_EDIT_MELEE,
    CTRL_EDIT_RANGE,
    CTRL_EDIT_HEALTH,
    CTRL_EDIT_SPEED,
    CTRL_EDIT_DEFENSE,
    CTRL_EDIT_MANA,
    CTRL_SUBMIT,
    CTRL_CANCEL,
    CTRL_END_RUN
};

enum RunModeControlId {
    CTRL_RUN_MANUAL = 3001,
    CTRL_RUN_AUTO,
    CTRL_RUN_RESET,
    CTRL_RUN_EXIT
};

enum ResetConfirmControlId {
    CTRL_RESET_EDIT = 4001,
    CTRL_RESET_CONFIRM,
    CTRL_RESET_CANCEL
};

struct PopupState {
    std::array<HWND, 9> edits;
    UserInteractionInput* output;
    bool askDeath;
    bool manualMode;
    double lockedHealth;
    bool submitted;
    bool cancelled;
};

struct RunModePopupState {
    RunMode selected;
    bool submitted;
    bool cancelled;
};

struct ResetConfirmPopupState {
    bool confirmed;
    bool submitted;
    bool cancelled;
    HWND edit;
};

enum AutoProfileControlId {
    CTRL_SCENARIO_1 = 2001,
    CTRL_SCENARIO_2,
    CTRL_SCENARIO_3,
    CTRL_SCENARIO_4,
    CTRL_SCENARIO_OVERPOWERED,
    CTRL_SCENARIO_RANDOM,
    CTRL_SCENARIO_CANCEL,
    CTRL_SCENARIO_CONFIRM,
    CTRL_SCENARIO_GAMES_EDIT
};

struct AutoProfilePopupState {
    AutoRunProfile selected;
    bool submitted;
    bool cancelled;
    HWND descriptionLabel;
    HWND gamesEdit;
    AutoRunProfile hoveredProfile;
    int gamesToRun;
};

// ============================================================
// HELPERS (PRIVATE)
// ============================================================

static bool parseDoubleFromEdit(HWND edit, double& value) {
    char buffer[128] = {0};
    GetWindowTextA(edit, buffer, 127);
    std::stringstream ss(buffer);
    ss >> value;
    return !(ss.fail() || !ss.eof());
}

static bool parseIntFromEdit(HWND edit, int& value) {
    char buffer[64] = {0};
    GetWindowTextA(edit, buffer, 63);
    std::stringstream ss(buffer);
    ss >> value;
    return !(ss.fail() || !ss.eof());
}

static bool textEqualsYes(HWND edit) {
    char buffer[64] = {0};
    GetWindowTextA(edit, buffer, 63);
    return std::string(buffer) == "Yes";
}

static LRESULT CALLBACK RunModePopupProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    RunModePopupState* state = reinterpret_cast<RunModePopupState*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

    switch (msg) {
        case WM_NCCREATE: {
            CREATESTRUCT* createStruct = reinterpret_cast<CREATESTRUCT*>(lParam);
            SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(createStruct->lpCreateParams));
            return TRUE;
        }

        case WM_CREATE: {
            CreateWindowA("STATIC", "Choose Run Mode", WS_VISIBLE | WS_CHILD,
                20, 16, 220, 22, hwnd, nullptr, nullptr, nullptr);

            CreateWindowA("BUTTON", "Manual", WS_VISIBLE | WS_CHILD | BS_DEFPUSHBUTTON,
                20, 50, 90, 32, hwnd, (HMENU)CTRL_RUN_MANUAL, nullptr, nullptr);
            CreateWindowA("BUTTON", "Auto", WS_VISIBLE | WS_CHILD,
                120, 50, 90, 32, hwnd, (HMENU)CTRL_RUN_AUTO, nullptr, nullptr);
            CreateWindowA("BUTTON", "Reset Training", WS_VISIBLE | WS_CHILD,
                20, 95, 190, 32, hwnd, (HMENU)CTRL_RUN_RESET, nullptr, nullptr);
            CreateWindowA("BUTTON", "Exit", WS_VISIBLE | WS_CHILD,
                20, 140, 190, 32, hwnd, (HMENU)CTRL_RUN_EXIT, nullptr, nullptr);
            return 0;
        }

        case WM_COMMAND: {
            if (!state) return 0;

            const int id = LOWORD(wParam);
            if (id == CTRL_RUN_MANUAL) {
                state->selected = RUN_MODE_MANUAL;
                state->submitted = true;
                DestroyWindow(hwnd);
            } else if (id == CTRL_RUN_AUTO) {
                state->selected = RUN_MODE_AUTO;
                state->submitted = true;
                DestroyWindow(hwnd);
            } else if (id == CTRL_RUN_RESET) {
                state->selected = RUN_MODE_RESET;
                state->submitted = true;
                DestroyWindow(hwnd);
            } else if (id == CTRL_RUN_EXIT) {
                state->selected = RUN_MODE_CANCEL;
                state->cancelled = true;
                DestroyWindow(hwnd);
            }
            return 0;
        }

        case WM_CLOSE:
            if (state) {
                state->selected = RUN_MODE_CANCEL;
                state->cancelled = true;
            }
            DestroyWindow(hwnd);
            return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

static LRESULT CALLBACK ResetConfirmPopupProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    ResetConfirmPopupState* state = reinterpret_cast<ResetConfirmPopupState*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

    switch (msg) {
        case WM_NCCREATE: {
            CREATESTRUCT* createStruct = reinterpret_cast<CREATESTRUCT*>(lParam);
            SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(createStruct->lpCreateParams));
            return TRUE;
        }

        case WM_CREATE: {
            ResetConfirmPopupState* s = (ResetConfirmPopupState*)((CREATESTRUCT*)lParam)->lpCreateParams;

            CreateWindowA("STATIC", "Type Yes to confirm reset:", WS_VISIBLE | WS_CHILD,
                20, 20, 220, 22, hwnd, nullptr, nullptr, nullptr);

            s->edit = CreateWindowA("EDIT", "",
                WS_VISIBLE | WS_CHILD | WS_BORDER | ES_AUTOHSCROLL,
                20, 48, 220, 24, hwnd, (HMENU)CTRL_RESET_EDIT, nullptr, nullptr);

            CreateWindowA("BUTTON", "Confirm", WS_VISIBLE | WS_CHILD | BS_DEFPUSHBUTTON,
                20, 86, 100, 30, hwnd, (HMENU)CTRL_RESET_CONFIRM, nullptr, nullptr);
            CreateWindowA("BUTTON", "Cancel", WS_VISIBLE | WS_CHILD,
                140, 86, 100, 30, hwnd, (HMENU)CTRL_RESET_CANCEL, nullptr, nullptr);
            return 0;
        }

        case WM_COMMAND: {
            if (!state) return 0;

            const int id = LOWORD(wParam);
            if (id == CTRL_RESET_CONFIRM) {
                if (!textEqualsYes(state->edit)) {
                    MessageBoxA(hwnd, "Please type exactly: Yes", "Confirmation Required", MB_OK | MB_ICONWARNING);
                    return 0;
                }
                state->confirmed = true;
                state->submitted = true;
                DestroyWindow(hwnd);
            } else if (id == CTRL_RESET_CANCEL) {
                state->cancelled = true;
                DestroyWindow(hwnd);
            }
            return 0;
        }

        case WM_CLOSE:
            if (state) {
                state->cancelled = true;
            }
            DestroyWindow(hwnd);
            return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

// ============================================================
// AUTO PROFILE WINDOW PROC
// ============================================================

static LRESULT CALLBACK AutoProfilePopupProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    AutoProfilePopupState* state = reinterpret_cast<AutoProfilePopupState*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

    switch (msg) {
        case WM_NCCREATE: {
            CREATESTRUCT* createStruct = reinterpret_cast<CREATESTRUCT*>(lParam);
            SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(createStruct->lpCreateParams));
            return TRUE;
        }

        case WM_CREATE: {
            CreateWindowA("STATIC", "Choose Auto Run Scenario", WS_VISIBLE | WS_CHILD,
                20, 14, 320, 22, hwnd, nullptr, nullptr, nullptr);

            CreateWindowA("BUTTON", "Scenario 1", WS_VISIBLE | WS_CHILD | BS_DEFPUSHBUTTON,
                20, 50, 95, 30, hwnd, (HMENU)CTRL_SCENARIO_1, nullptr, nullptr);
            CreateWindowA("BUTTON", "Scenario 2", WS_VISIBLE | WS_CHILD,
                125, 50, 95, 30, hwnd, (HMENU)CTRL_SCENARIO_2, nullptr, nullptr);
            CreateWindowA("BUTTON", "Scenario 3", WS_VISIBLE | WS_CHILD,
                230, 50, 95, 30, hwnd, (HMENU)CTRL_SCENARIO_3, nullptr, nullptr);
            CreateWindowA("BUTTON", "Scenario 4", WS_VISIBLE | WS_CHILD,
                335, 50, 95, 30, hwnd, (HMENU)CTRL_SCENARIO_4, nullptr, nullptr);

            CreateWindowA("BUTTON", "Random", WS_VISIBLE | WS_CHILD,
                100, 100, 120, 30, hwnd, (HMENU)CTRL_SCENARIO_RANDOM, nullptr, nullptr);
            CreateWindowA("BUTTON", "Overpowered", WS_VISIBLE | WS_CHILD,
                230, 100, 120, 30, hwnd, (HMENU)CTRL_SCENARIO_OVERPOWERED, nullptr, nullptr);

            state->descriptionLabel = CreateWindowA("STATIC", "Select a scenario to view details",
                WS_VISIBLE | WS_CHILD | SS_LEFT | WS_BORDER,
                20, 150, 420, 80, hwnd, nullptr, nullptr, nullptr);

            CreateWindowA("STATIC", "Games to Run:", WS_VISIBLE | WS_CHILD,
                20, 240, 120, 22, hwnd, nullptr, nullptr, nullptr);

            state->gamesEdit = CreateWindowA("EDIT", "1",
                WS_VISIBLE | WS_CHILD | WS_BORDER | ES_AUTOHSCROLL,
                130, 238, 70, 24, hwnd, (HMENU)CTRL_SCENARIO_GAMES_EDIT, nullptr, nullptr);

            CreateWindowA("BUTTON", "Confirm", WS_VISIBLE | WS_CHILD,
                220, 235, 80, 30, hwnd, (HMENU)CTRL_SCENARIO_CONFIRM, nullptr, nullptr);
            CreateWindowA("BUTTON", "Back", WS_VISIBLE | WS_CHILD,
                310, 235, 80, 30, hwnd, (HMENU)CTRL_SCENARIO_CANCEL, nullptr, nullptr);
            return 0;
        }

        case WM_COMMAND: {
            if (!state) return 0;

            int id = LOWORD(wParam);

            if (id == CTRL_SCENARIO_1) {
                state->hoveredProfile = AUTO_PROFILE_SCENARIO_1;
                SetWindowTextA(state->descriptionLabel,
                    "Scenario 1: Weak Profile\n\n"
                    "Very low damage, average survivability.\n"
                    "Melee: 1.5 | Range: 1.5\n"
                    "Speed: 1.5 | Defense: 0.5\n"
                    "Survival Time: 245s");
            }
            else if (id == CTRL_SCENARIO_2) {
                state->hoveredProfile = AUTO_PROFILE_SCENARIO_2;
                SetWindowTextA(state->descriptionLabel,
                    "Scenario 2: Strong Melee Profile\n\n"
                    "High melee damage, low speed, solid defense.\n"
                    "Melee: 6.0 (STRONG) | Range: 1.0\n"
                    "Speed: 1.0 | Defense: 2.0\n"
                    "Survival Time: 120s");
            }
            else if (id == CTRL_SCENARIO_3) {
                state->hoveredProfile = AUTO_PROFILE_SCENARIO_3;
                SetWindowTextA(state->descriptionLabel,
                    "Scenario 3: Strong Ranged Profile\n\n"
                    "High ranged damage, fast, fragile.\n"
                    "Melee: 1.0 | Range: 6.0 (STRONG)\n"
                    "Speed: 2.0 | Defense: 0.5\n"
                    "Survival Time: 130s");
            }
            else if (id == CTRL_SCENARIO_4) {
                state->hoveredProfile = AUTO_PROFILE_SCENARIO_4;
                SetWindowTextA(state->descriptionLabel,
                    "Scenario 4: Balanced Profile\n\n"
                    "Well-rounded stats across the board.\n"
                    "Melee: 5.0 | Range: 3.5\n"
                    "Speed: 1.5 | Defense: 0.5\n"
                    "Survival Time: 140s");
            }
            else if (id == CTRL_SCENARIO_RANDOM) {
                state->hoveredProfile = AUTO_PROFILE_RANDOM;
                SetWindowTextA(state->descriptionLabel,
                    "Complete Random Profile\n\n"
                    "All stats are randomized each run.\n"
                    "Unpredictable strengths and weaknesses.");
            }
            else if (id == CTRL_SCENARIO_OVERPOWERED) {
                state->hoveredProfile = AUTO_PROFILE_OVERPOWERED;
                SetWindowTextA(state->descriptionLabel,
                    "Overpowered Profile\n\n"
                    "Extremely strong in all areas (For Training Purposes).\n"
                    "Melee: 10 | Range: 10\n"
                    "Speed: 4 | Defense: 2\n"
                    "Mana: 10 | Survival Time: 220s");
            }
            else if (id == CTRL_SCENARIO_CONFIRM) {
                if (state->hoveredProfile != AUTO_PROFILE_CANCEL) {
                    int parsedGames = 1;
                    if (!parseIntFromEdit(state->gamesEdit, parsedGames) || parsedGames <= 0) {
                        MessageBoxA(hwnd, "Enter a valid games count (1 or more).", "Invalid Input", MB_OK | MB_ICONERROR);
                        return 0;
                    }

                    state->selected = state->hoveredProfile;
                    state->gamesToRun = parsedGames;
                    state->submitted = true;
                    DestroyWindow(hwnd);
                }
            }
            else if (id == CTRL_SCENARIO_CANCEL) {
                state->selected = AUTO_PROFILE_CANCEL;
                state->cancelled = true;
                DestroyWindow(hwnd);
            }
            return 0;
        }

        case WM_CLOSE:
            if (state) {
                state->selected = AUTO_PROFILE_CANCEL;
                state->cancelled = true;
            }
            DestroyWindow(hwnd);
            return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

// ============================================================
// INTERACTION WINDOW PROC
// ============================================================

static LRESULT CALLBACK InteractionPopupProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    PopupState* state = reinterpret_cast<PopupState*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

    switch (msg) {
        case WM_NCCREATE: {
            CREATESTRUCT* cs = reinterpret_cast<CREATESTRUCT*>(lParam);
            SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)cs->lpCreateParams);
            return TRUE;
        }

        case WM_CREATE: {
            PopupState* s = (PopupState*)((CREATESTRUCT*)lParam)->lpCreateParams;

            const char* labels[9] = {
                "Time", "Physical", "Magic", "Melee", "Range",
                "Health", "Speed", "Defense", "Mana"
            };

            std::array<std::string, 9> defaultValues = {
                "0", "0", "0", "0", "0", "0", "0", "0", "0"
            };

            if (s->output) {
                std::ostringstream oss;
                oss << std::fixed << std::setprecision(2);

                oss.str(""); oss.clear(); oss << s->output->timeSurvived; defaultValues[0] = oss.str();
                oss.str(""); oss.clear(); oss << s->output->physicalDamage; defaultValues[1] = oss.str();
                oss.str(""); oss.clear(); oss << s->output->magicDamage; defaultValues[2] = oss.str();
                oss.str(""); oss.clear(); oss << s->output->meleeDamage; defaultValues[3] = oss.str();
                oss.str(""); oss.clear(); oss << s->output->rangeDamage; defaultValues[4] = oss.str();
                oss.str(""); oss.clear(); oss << s->output->health; defaultValues[5] = oss.str();
                oss.str(""); oss.clear(); oss << s->output->speed; defaultValues[6] = oss.str();
                oss.str(""); oss.clear(); oss << s->output->defense; defaultValues[7] = oss.str();
                oss.str(""); oss.clear(); oss << s->output->dungeonMana; defaultValues[8] = oss.str();
            }

            int y = 20;
            for (int i = 0; i < 9; i++) {
                CreateWindowA("STATIC", labels[i], WS_VISIBLE | WS_CHILD,
                    20, y, 120, 20, hwnd, nullptr, nullptr, nullptr);

                s->edits[i] = CreateWindowA("EDIT", defaultValues[i].c_str(),
                    WS_VISIBLE | WS_CHILD | WS_BORDER | ES_AUTOHSCROLL,
                    150, y, 120, 20, hwnd, nullptr, nullptr, nullptr);

                y += 30;
            }

            if (s->manualMode) {
                SetWindowTextA(s->edits[1], "AI Simulated");
                EnableWindow(s->edits[1], FALSE);
                SetWindowTextA(s->edits[2], "AI Simulated");
                EnableWindow(s->edits[2], FALSE);

                std::ostringstream healthValue;
                healthValue << std::fixed << std::setprecision(2) << s->lockedHealth;
                SetWindowTextA(s->edits[5], healthValue.str().c_str());
                EnableWindow(s->edits[5], FALSE);

                // Manual mode mana follows system progression and is display-only.
                EnableWindow(s->edits[8], FALSE);
            }

            CreateWindowA("BUTTON", "Submit", WS_VISIBLE | WS_CHILD | BS_DEFPUSHBUTTON,
                80, y, 80, 30, hwnd, (HMENU)CTRL_SUBMIT, nullptr, nullptr);

            CreateWindowA("BUTTON", "Cancel", WS_VISIBLE | WS_CHILD,
                180, y, 80, 30, hwnd, (HMENU)CTRL_CANCEL, nullptr, nullptr);

            if (s->manualMode) {
                CreateWindowA("BUTTON", "End Manual Run", WS_VISIBLE | WS_CHILD,
                    80, y + 40, 180, 30, hwnd, (HMENU)CTRL_END_RUN, nullptr, nullptr);
            }

            return 0;
        }

        case WM_COMMAND: {
            if (!state) return 0;

            int id = LOWORD(wParam);

            if (id == CTRL_SUBMIT) {
                UserInteractionInput data = {};

                for (int i = 0; i < 9; i++) {
                    double val = 0.0;
                    if (state->manualMode && (i == 1 || i == 2)) {
                        ((double*)&data)[i] = 0.0;
                        continue;
                    }
                    if (state->manualMode && i == 5) {
                        ((double*)&data)[i] = state->lockedHealth;
                        continue;
                    }
                    if (state->manualMode && i == 8) {
                        ((double*)&data)[i] = state->output->dungeonMana;
                        continue;
                    }
                    if (!parseDoubleFromEdit(state->edits[i], val)) {
                        MessageBoxA(hwnd, "Please enter valid numeric values in all fields.", "Invalid Input", MB_OK | MB_ICONERROR);
                        return 0;
                    }

                    ((double*)&data)[i] = val;
                }

                data.healingReceived = 0.0;
                data.endManualRunRequested = false;

                if (state->askDeath) {
                    int deathChoice = MessageBoxA(
                        hwnd,
                        "Did the player die in this interaction?",
                        "Player Outcome",
                        MB_YESNOCANCEL | MB_ICONQUESTION
                    );

                    if (deathChoice == IDCANCEL) {
                        return 0;
                    }

                    data.playerDied = (deathChoice == IDYES);
                } else {
                    data.playerDied = false;
                }

                *state->output = data;
                state->submitted = true;
                DestroyWindow(hwnd);
            }
            else if (id == CTRL_END_RUN) {
                state->output->endManualRunRequested = true;
                state->submitted = true;
                DestroyWindow(hwnd);
            }
            else if (id == CTRL_CANCEL) {
                state->cancelled = true;
                DestroyWindow(hwnd);
            }
            return 0;
        }

        case WM_CLOSE:
            if (state) {
                state->cancelled = true;
            }
            DestroyWindow(hwnd);
            return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

// ============================================================
// PUBLIC FUNCTIONS (WINDOWS)
// ============================================================

DifficultyMode promptDifficultyModePopup() {
    int result = MessageBoxA(
        nullptr,
        "Yes = Easy (AI relearns from scratch)\nNo = Hard (AI keeps memory)\nCancel = Exit",
        "Difficulty",
        MB_YESNOCANCEL | MB_ICONQUESTION
    );

    if (result == IDYES) return DIFFICULTY_EASY;
    if (result == IDNO) return DIFFICULTY_HARD;
    return DIFFICULTY_CANCEL;
}

RunMode promptRunModePopup() {
    static bool classRegistered = false;
    const char* className = "DungeonAIRunModePopup";
    HINSTANCE hInstance = GetModuleHandle(nullptr);

    if (!classRegistered) {
        WNDCLASSA wc = {};
        wc.lpfnWndProc = RunModePopupProc;
        wc.hInstance = hInstance;
        wc.lpszClassName = className;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
        RegisterClassA(&wc);
        classRegistered = true;
    }

    RunModePopupState state = {RUN_MODE_CANCEL, false, false};

    HWND hwnd = CreateWindowExA(
        WS_EX_DLGMODALFRAME,
        className,
        "Run Mode",
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
        CW_USEDEFAULT, CW_USEDEFAULT, 250, 230,
        nullptr,
        nullptr,
        hInstance,
        &state
    );

    if (!hwnd) {
        return RUN_MODE_CANCEL;
    }

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);

    MSG msg;
    while (!state.submitted && !state.cancelled && IsWindow(hwnd) && GetMessage(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return state.selected;
}

bool confirmResetTrainingDataPopup() {
    static bool classRegistered = false;
    const char* className = "DungeonAIResetConfirmPopup";
    HINSTANCE hInstance = GetModuleHandle(nullptr);

    if (!classRegistered) {
        WNDCLASSA wc = {};
        wc.lpfnWndProc = ResetConfirmPopupProc;
        wc.hInstance = hInstance;
        wc.lpszClassName = className;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
        RegisterClassA(&wc);
        classRegistered = true;
    }

    ResetConfirmPopupState state = {false, false, false, nullptr};

    HWND hwnd = CreateWindowExA(
        WS_EX_DLGMODALFRAME,
        className,
        "Confirm Reset",
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
        CW_USEDEFAULT, CW_USEDEFAULT, 280, 180,
        nullptr,
        nullptr,
        hInstance,
        &state
    );

    if (!hwnd) {
        return false;
    }

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);

    MSG msg;
    while (!state.submitted && !state.cancelled && IsWindow(hwnd) && GetMessage(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return state.confirmed;
}

AutoRunProfile promptAutoRunProfilePopup(int& gamesToRun) {
    static bool classRegistered = false;
    const char* className = "DungeonAIAutoProfilePopup";
    HINSTANCE hInstance = GetModuleHandle(nullptr);

    if (!classRegistered) {
        WNDCLASSA wc = {};
        wc.lpfnWndProc = AutoProfilePopupProc;
        wc.hInstance = hInstance;
        wc.lpszClassName = className;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
        RegisterClassA(&wc);
        classRegistered = true;
    }

    AutoProfilePopupState state = {AUTO_PROFILE_CANCEL, false, false, nullptr, nullptr, AUTO_PROFILE_CANCEL, 1};

    HWND hwnd = CreateWindowExA(
        WS_EX_DLGMODALFRAME,
        className,
        "Auto Run Scenario Selection",
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
        CW_USEDEFAULT, CW_USEDEFAULT, 470, 330,
        nullptr,
        nullptr,
        hInstance,
        &state
    );

    if (!hwnd) {
        return AUTO_PROFILE_CANCEL;
    }

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);

    MSG msg;
    while (!state.submitted && !state.cancelled && IsWindow(hwnd) && GetMessage(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    gamesToRun = (state.gamesToRun > 0) ? state.gamesToRun : 1;

    return state.selected;
}

bool showInteractionInputPopup(
    UserInteractionInput& output,
    bool askDeathChoice,
    bool manualMode,
    double lockedHealth
) {
    static bool classRegistered = false;
    const char* className = "DungeonAIInteractionPopup";
    HINSTANCE hInstance = GetModuleHandle(nullptr);

    if (!classRegistered) {
        WNDCLASSA wc = {};
        wc.lpfnWndProc = InteractionPopupProc;
        wc.hInstance = hInstance;
        wc.lpszClassName = className;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
        RegisterClassA(&wc);
        classRegistered = true;
    }

    PopupState state = {{}, &output, askDeathChoice, manualMode, lockedHealth, false, false};

    HWND hwnd = CreateWindowExA(
        WS_EX_DLGMODALFRAME,
        className,
        manualMode ? "Dungeon AI - Manual Round Input" : "Dungeon AI - Interaction Input",
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
        CW_USEDEFAULT, CW_USEDEFAULT, 340, manualMode ? 440 : 390,
        nullptr,
        nullptr,
        hInstance,
        &state
    );

    if (!hwnd) {
        return false;
    }

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);

    MSG msg;
    while (!state.submitted && !state.cancelled && IsWindow(hwnd) && GetMessage(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return state.submitted;
}

void showAutoRunSummaryWindow(const std::string& summaryText) {
    MessageBoxA(nullptr, summaryText.c_str(), "Summary", MB_OK);
}

#else

// ============================================================
// CONSOLE FALLBACK (NON-WINDOWS)
// ============================================================

DifficultyMode promptDifficultyModePopup() {
    char c;
    std::cin >> c;
    if (c == 'e' || c == 'E') return DIFFICULTY_EASY;
    if (c == 'h' || c == 'H') return DIFFICULTY_HARD;
    return DIFFICULTY_CANCEL;
}

RunMode promptRunModePopup() {
    char c;
    std::cin >> c;
    if (c == 'm') return RUN_MODE_MANUAL;
    if (c == 'a') return RUN_MODE_AUTO;
    if (c == 'r') return RUN_MODE_RESET;
    return RUN_MODE_CANCEL;
}

bool confirmResetTrainingDataPopup() {
    std::string text;
    std::cin >> text;
    return text == "Yes";
}

AutoRunProfile promptAutoRunProfilePopup(int& gamesToRun) {
    int x;
    std::cin >> x >> gamesToRun;
    if (gamesToRun <= 0) {
        gamesToRun = 1;
    }
    return (AutoRunProfile)x;
}

bool showInteractionInputPopup(
    UserInteractionInput& output,
    bool askDeathChoice,
    bool manualMode,
    double lockedHealth
) {
    (void)askDeathChoice;
    (void)manualMode;
    (void)lockedHealth;
    std::cin >> output.timeSurvived
             >> output.physicalDamage
             >> output.magicDamage
             >> output.meleeDamage
             >> output.rangeDamage
             >> output.health
             >> output.speed
             >> output.defense
             >> output.dungeonMana;

    output.playerDied = false;
    output.endManualRunRequested = false;
    return true;
}

void showAutoRunSummaryWindow(const std::string& summaryText) {
    std::cout << summaryText << "\n";
}

#endif