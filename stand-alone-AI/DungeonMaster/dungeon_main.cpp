// ============================================================================
// DUNGEON MASTER - AI ENEMY SPAWNING SYSTEM
// ============================================================================
// This is a game AI system that uses machine learning to decide what enemies
// to spawn based on player statistics.
//
// INPUTS (10 features):
//   1. Physical damage done to player
//   2. Magic damage done to player
//   3. Time player took (survival time)
//   4. Player weapon melee damage
//   5. Player weapon range damage
//   6. Player health
//   7. Player speed
//   8. Player defense
//   9. Healing received from enemies
//   10. Dungeon mana available
//
// OUTPUTS (Enemy spawn counts):
//   - Uses all configured enemy entries from DungeonAI::initializeEnemyTypes()
//   - Names/stats/costs come from DungeonAI enemy definitions (not hardcoded here)
//
// GOAL: Spawn enemies that:
//   - Maximize time player survives (more engaging gameplay)
//   - Maximize damage to player (challenging but fair)
//   - Use mana efficiently (resource management)
// ============================================================================

#include "DungeonAI.h"
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <numeric>
#include <random>
#include <sstream>
#include <string>
#include <cstdlib>

#include "GraphUtils.h"
#include "PopupUI.h"
#include "GameTypes.h"

#ifdef _WIN32
#include <windows.h>
#endif

struct Range {
    double min;
    double max;
};

struct AutoRunConfig {
    double baseTimeSurvived;
    double baseMeleeDamage;
    double baseRangeDamage;
    double baseHealth;
    double baseSpeed;
    double baseDefense;
    double baseDungeonMana;

    Range timeIncreasePerRun;
    Range meleeIncreasePerRun;
    Range rangeIncreasePerRun;
    Range speedIncreasePerRun;
    Range defenseIncreasePerRun;
    Range manaIncreasePerRun;

    double healthLossFactor;
    double deathHealthThreshold;
    int maxRuns;
};

struct AutoRunRoundLog {
    int runNumber;
    std::vector<int> spawns;
    int manaUsed;
    double simulatedDamage;
    double healedAmount;
    int healProcCount;
    double aiScorePercent;
    double endHealth;
    bool recoveredAtRound10;
    bool playerDied;
};

// ============================================================================
// AUTO-RUN BASE STATS (MODIFY HERE)
// ============================================================================
// Change these values to tune auto simulation behavior.
static AutoRunConfig getAutoRunConfig() {
    AutoRunConfig cfg = {};

    cfg.baseTimeSurvived = 90.0;
    cfg.baseMeleeDamage = 15.0;
    cfg.baseRangeDamage = 10.0;
    cfg.baseHealth = 50.0;
    cfg.baseSpeed = 1.5;
    cfg.baseDefense = 0.5;
    cfg.baseDungeonMana = 10.0;

    // Ranges instead of fixed values
    cfg.timeIncreasePerRun = {6.0, 10.0};
    cfg.meleeIncreasePerRun = {0.2, 0.6};
    cfg.rangeIncreasePerRun = {0.1, 0.5};
    cfg.speedIncreasePerRun = {0.1, 0.3};
    cfg.defenseIncreasePerRun = {0.0, 0.0};
    cfg.manaIncreasePerRun = {10.0, 15.0};

    cfg.healthLossFactor = 0.28;
    cfg.deathHealthThreshold = 1.0;
    cfg.maxRuns = 50;

    return cfg;
}

double getRandomInRange(const Range& r) {
    static std::mt19937 generator(std::random_device{}());
    std::uniform_real_distribution<double> distribution(r.min, r.max);
    return distribution(generator);
}

static double getRandomInBounds(double minValue, double maxValue) {
    return getRandomInRange({minValue, maxValue});
}

static void applyAutoRunProfile(AutoRunConfig& cfg, AutoRunProfile profile) {
    if (profile == AUTO_PROFILE_SCENARIO_1) { // Weak profile
        cfg.baseTimeSurvived = 245.0;
        cfg.baseMeleeDamage = 1.5;
        cfg.baseRangeDamage = 1.5;
        cfg.baseHealth = 50.0;
        cfg.baseSpeed = 1.5;
        cfg.baseDefense = 0.5;
        cfg.baseDungeonMana = 10.0;
    } else if (profile == AUTO_PROFILE_SCENARIO_2) { //Strong melee
        cfg.baseTimeSurvived = 120.0;
        cfg.baseMeleeDamage = 6.0;
        cfg.baseRangeDamage = 1.0;
        cfg.baseHealth = 50.0;
        cfg.baseSpeed = 1.0;
        cfg.baseDefense = 2.0;
        cfg.baseDungeonMana = 10.0;
    } else if (profile == AUTO_PROFILE_SCENARIO_3) { //Strong ranged
        cfg.baseTimeSurvived = 130.0;
        cfg.baseMeleeDamage = 1.0;
        cfg.baseRangeDamage = 6.0;
        cfg.baseHealth = 50.0;
        cfg.baseSpeed = 2.0;
        cfg.baseDefense = 0.5;
        cfg.baseDungeonMana = 10.0;
    } else if (profile == AUTO_PROFILE_SCENARIO_4) { // Balanced
        cfg.baseTimeSurvived = 140.0;
        cfg.baseMeleeDamage = 5.0;
        cfg.baseRangeDamage = 3.5;
        cfg.baseHealth = 50.0;
        cfg.baseSpeed = 1.5;
        cfg.baseDefense = 0.5;
        cfg.baseDungeonMana = 10.0;
    } else if (profile == AUTO_PROFILE_OVERPOWERED) {
        cfg.baseTimeSurvived = 220.0;
        cfg.baseMeleeDamage = 10.0;
        cfg.baseRangeDamage = 10.0;
        cfg.baseHealth = 150.0;
        cfg.baseSpeed = 4.0;
        cfg.baseDefense = 2.0;
        cfg.baseDungeonMana = 10.0;
    } else if (profile == AUTO_PROFILE_RANDOM) {
        cfg.baseTimeSurvived = getRandomInBounds(30.0, 180.0);
        cfg.baseMeleeDamage = getRandomInBounds(3.0, 30.0);
        cfg.baseRangeDamage = getRandomInBounds(3.0, 30.0);
        cfg.baseHealth = getRandomInBounds(50.0, 50.0);
        cfg.baseSpeed = getRandomInBounds(5.0, 16.0);
        cfg.baseDefense = getRandomInBounds(4.0, 28.0);
        cfg.baseDungeonMana = getRandomInBounds(10.0, 10.0);

        cfg.timeIncreasePerRun = {4.0, 12.0};
        cfg.meleeIncreasePerRun = {0.1, 0.9};
        cfg.rangeIncreasePerRun = {0.1, 0.9};
        cfg.speedIncreasePerRun = {0.05, 0.5};
        cfg.defenseIncreasePerRun = {0.05, 0.7};
        cfg.manaIncreasePerRun = {5.0, 10.0};
    }
}

static UserInteractionInput buildAutoRunInput(
    const AutoRunConfig& cfg,
    int runNumber,
    double currentHealth,
    double lastPhysicalDamage,
    double lastMagicDamage,
    double lastHealingReceived
) {
    UserInteractionInput input = {};
    const int runOffset = std::max(0, runNumber - 1);

    // Accumulate random increases per run
    double timeBonus = 0.0;
    double meleeBonus = 0.0;
    double rangeBonus = 0.0;
    double speedBonus = 0.0;
    double defenseBonus = 0.0;
    double manaBonus = 0.0;

    for (int i = 0; i < runOffset; ++i) {
        timeBonus += getRandomInRange(cfg.timeIncreasePerRun);
        meleeBonus += getRandomInRange(cfg.meleeIncreasePerRun);
        rangeBonus += getRandomInRange(cfg.rangeIncreasePerRun);
        speedBonus += getRandomInRange(cfg.speedIncreasePerRun);
        defenseBonus += getRandomInRange(cfg.defenseIncreasePerRun);
        manaBonus += getRandomInRange(cfg.manaIncreasePerRun);
    }

    input.timeSurvived = cfg.baseTimeSurvived + timeBonus;
    input.physicalDamage = std::max(0.0, lastPhysicalDamage);
    input.magicDamage = std::max(0.0, lastMagicDamage);
    input.meleeDamage = cfg.baseMeleeDamage + meleeBonus;
    input.rangeDamage = cfg.baseRangeDamage + rangeBonus;
    input.health = std::max(0.0, currentHealth);
    input.speed = std::max(0.5, cfg.baseSpeed + speedBonus);
    input.defense = std::max(0.0, cfg.baseDefense + defenseBonus);
    input.healingReceived = std::max(0.0, lastHealingReceived);
    input.dungeonMana = cfg.baseDungeonMana + manaBonus;
    input.playerDied = false;
    input.endManualRunRequested = false;

    return input;
}

static std::string buildAutoRunSummaryText(const std::vector<RunScores>& runScores) {
    std::ostringstream oss;
    oss << "Auto Run Results (until player death)\n\n";
    for (const auto& run : runScores) {
        oss << "Run " << run.runNumber
            << " | AI Score: " << std::fixed << std::setprecision(2) << run.aiScorePercent << "/100"
            << " | Player Score: " << std::fixed << std::setprecision(2) << run.playerScorePercent << "/100"
            << " | Died: " << (run.playerDied ? "Yes" : "No")
            << "\n";
    }
    return oss.str();
}

static void launchPythonMetricsGraphs(const std::string& csvPath, int gameNumber, int endGameNumber = -1) {
    std::ostringstream argBuilder;
    argBuilder << "\"" << csvPath << "\" " << gameNumber;
    if (endGameNumber >= gameNumber && gameNumber > 0) {
        argBuilder << " " << endGameNumber;
    }
    const std::string args = argBuilder.str();

#ifdef _WIN32
    const std::string pyLauncherCmd = "py -3 plot_metrics.py " + args;
    if (std::system(pyLauncherCmd.c_str()) == 0) {
        return;
    }
#endif

    const std::string pythonCmd = "python plot_metrics.py " + args;
    if (std::system(pythonCmd.c_str()) == 0) {
        return;
    }

    const std::string python3Cmd = "python3 plot_metrics.py " + args;
    if (std::system(python3Cmd.c_str()) != 0) {
        std::cout << "Warning: metrics export succeeded, but graph script did not run.\n";
        std::cout << "Run manually: python plot_metrics.py " << args << "\n";
    }
}

static std::string buildSpawnListText(const std::vector<int>& spawns, const std::vector<Enemy>& enemyTypes) {
    std::ostringstream oss;
    const int count = std::min(static_cast<int>(spawns.size()), static_cast<int>(enemyTypes.size()));
    bool wroteAny = false;

    for (int i = 0; i < count; ++i) {
        const int spawnCount = std::max(0, spawns[i]);
        if (spawnCount <= 0) {
            continue;
        }
        if (wroteAny) {
            oss << ", ";
        }
        oss << enemyTypes[i].name << "=" << spawnCount;
        wroteAny = true;
    }

    if (!wroteAny) {
        oss << "None";
    }
    return oss.str();
}

static std::string buildSpawnCsvCountsText(const std::vector<int>& spawns, const std::vector<Enemy>& enemyTypes) {
    std::ostringstream oss;
    const int count = std::min(static_cast<int>(spawns.size()), static_cast<int>(enemyTypes.size()));
    bool wroteAny = false;

    for (int i = 0; i < count; ++i) {
        const int spawnCount = std::max(0, spawns[i]);
        if (wroteAny) {
            oss << "; ";
        }
        oss << enemyTypes[i].name << "=" << spawnCount;
        wroteAny = true;
    }

    if (!wroteAny) {
        oss << "None";
    }

    return oss.str();
}

static std::string buildAutoRunRoundLogText(const std::vector<AutoRunRoundLog>& logs, const std::vector<Enemy>& enemyTypes) {
    std::ostringstream oss;
    oss << "Auto Run Round-by-Round AI Actions\n\n";

    for (const auto& log : logs) {
        oss << "Run " << log.runNumber
            << " | Spawns [" << buildSpawnListText(log.spawns, enemyTypes) << "]"
            << " | Mana=" << log.manaUsed
            << " | SimDamage=" << std::fixed << std::setprecision(2) << log.simulatedDamage
            << " | Heal=" << std::fixed << std::setprecision(2) << log.healedAmount
            << " (procs=" << log.healProcCount << ")"
            << " | AI Score=" << std::fixed << std::setprecision(2) << log.aiScorePercent << "/100"
            << " | EndHealth=" << std::fixed << std::setprecision(2) << log.endHealth
            << " | Recovered=" << (log.recoveredAtRound10 ? "Yes" : "No")
            << " | Died=" << (log.playerDied ? "Yes" : "No")
            << "\n";
    }

    return oss.str();
}

static int calculateManaUsed(const std::vector<int>& spawns, const std::vector<Enemy>& enemyTypes) {
    int total = 0;
    const int count = std::min(static_cast<int>(spawns.size()), static_cast<int>(enemyTypes.size()));
    for (int i = 0; i < count; i++) {
        total += std::max(0, spawns[i]) * enemyTypes[i].manaCost;
    }
    return total;
}

static double simulateEndOfRoundHealing(
    const std::vector<int>& spawns,
    const std::vector<Enemy>& enemyTypes,
    double currentHealth,
    double maxHealth,
    int& healProcCount
) {
    healProcCount = 0;
    if (currentHealth <= 0.0 || maxHealth <= currentHealth) {
        return 0.0;
    }

    static std::mt19937 gen(std::random_device{}());
    const double missingHealthStart = std::max(0.0, maxHealth - currentHealth);
    double totalHealed = 0.0;
    double healthAfterHeals = currentHealth;

    const int count = std::min(static_cast<int>(spawns.size()), static_cast<int>(enemyTypes.size()));
    for (int i = 0; i < count; ++i) {
        const int spawnCount = std::max(0, spawns[i]);
        const int manaCost = std::max(1, enemyTypes[i].manaCost);
        const double procChance = std::min(1.0, 1.0 / static_cast<double>(manaCost));
        std::bernoulli_distribution healProc(procChance);

        for (int j = 0; j < spawnCount; ++j) {
            if (healthAfterHeals >= maxHealth) {
                break;
            }
            if (healProc(gen)) {
                const double remaining = std::max(0.0, maxHealth - healthAfterHeals);
                const double healAmount = std::min(remaining, static_cast<double>(manaCost));
                healthAfterHeals += healAmount;
                totalHealed += healAmount;
                healProcCount++;
            }
        }
    }

    return std::min(totalHealed, missingHealthStart);
}

struct CombatDamageResult {
    double totalDamage;
    double totalPhysicalDamage;
    double totalMagicDamage;
    std::vector<double> damageByEnemyType;
};

// Simulate actual combat damage from spawned enemies.
// This replaces hardcoded "damage taken" values with an RNG combat outcome.
// Optional player stat effects are included:
//  - Defense reduces per-hit damage as a flat subtraction.
//  - Speed gives dodge chance.
static CombatDamageResult simulateDamage(
    const std::vector<int>& spawns,
    const std::vector<Enemy>& enemyTypes,
    double playerDefense,
    double playerSpeed
) {
    CombatDamageResult result;
    result.totalDamage = 0.0;
    result.totalPhysicalDamage = 0.0;
    result.totalMagicDamage = 0.0;
    result.damageByEnemyType.assign(enemyTypes.size(), 0.0);
    static std::mt19937 gen(std::random_device{}());

    const double flatDefense = std::max(0.0, playerDefense);

    // Damage is now derived from actual enemy definitions (DungeonAI::getEnemyTypes).
    // We also make dodge chance relative to speed difference:
    // if player speed > enemy speed, dodge odds increase.
    auto applyHits = [&](int index, int count, const Enemy& enemy) {
        const double basePhysical = std::max(0.0, enemy.physicalDamage);
        const double baseMagic = std::max(0.0, enemy.magicDamage);
        const double baseDamage = std::max(0.0, basePhysical + baseMagic);
        const double physicalRatio = (baseDamage > 0.0) ? (basePhysical / baseDamage) : 0.0;
        const double magicRatio = (baseDamage > 0.0) ? (baseMagic / baseDamage) : 0.0;

        // Faster enemies hit more reliably.
        const double hitChance = std::min(std::max(0.35 + (enemy.speed * 0.15), 0.45), 0.95);

        // Random dodge chance, boosted when player is faster than attacker.
        const double speedDelta = playerSpeed - enemy.speed;
        const double dodgeChance = std::min(std::max(0.08 + (speedDelta * 0.08), 0.05), 0.85);

        std::bernoulli_distribution hit(hitChance);
        std::bernoulli_distribution dodge(dodgeChance);

        for (int i = 0; i < count; ++i) {
            if (!hit(gen)) {
                continue;
            }
            if (dodge(gen)) {
                continue;
            }

            double dealt = std::max(0.0, baseDamage - flatDefense);
            const double physicalDealt = dealt * physicalRatio;
            const double magicDealt = dealt * magicRatio;
            result.totalDamage += dealt;
            result.totalPhysicalDamage += physicalDealt;
            result.totalMagicDamage += magicDealt;
            if (index >= 0 && index < static_cast<int>(result.damageByEnemyType.size())) {
                result.damageByEnemyType[index] += dealt;
            }
        }
    };

    const int count = std::min(static_cast<int>(spawns.size()), static_cast<int>(enemyTypes.size()));
    for (int i = 0; i < count; ++i) {
        applyHits(i, std::max(0, spawns[i]), enemyTypes[i]);
    }

    return result;
}

static double calculatePlayerScorePercent(const UserInteractionInput& input) {
    const double totalDamageTaken = input.physicalDamage + input.magicDamage;
    const double survivalScore = std::min(input.timeSurvived / 300.0, 1.0);
    const double damageAvoidanceScore = 1.0 - std::min(totalDamageTaken / 300.0, 1.0);
    const double combatScore = std::min((input.meleeDamage + input.rangeDamage) / 60.0, 1.0);
    const double healthScore = std::min(input.health / 200.0, 1.0);
    const double speedScore = std::min(input.speed / 20.0, 1.0);
    const double defenseScore = std::min(input.defense / 50.0, 1.0);
    const double survivabilityScore = (healthScore + speedScore + defenseScore) / 3.0;

    double normalized =
        (0.40 * survivalScore) +
        (0.30 * damageAvoidanceScore) +
        (0.15 * combatScore) +
        (0.15 * survivabilityScore);
    if (input.playerDied) {
        normalized *= 0.6;
    }

    normalized = std::min(std::max(normalized, 0.0), 1.0);
    return normalized * 100.0;
}

bool RUN_SCENARIOS = false;

int main() {
    std::cout << "╔════════════════════════════════════════════════════════════╗\n";
    std::cout << "║         DUNGEON MASTER - AI SPAWNING SYSTEM                ║\n";
    std::cout << "║    Neural Network learns optimal enemy configurations      ║\n";
    std::cout << "╚════════════════════════════════════════════════════════════╝\n\n";

    // ========================================================================
    // STEP 1: CREATE AND INITIALIZE DUNGEON AI
    // ========================================================================
    // Available mana for spawning enemies (game resource)
    double AVAILABLE_MANA = 10.0;
    
    DungeonAI dungeonAI(AVAILABLE_MANA);
    const std::vector<Enemy>& enemyTypes = dungeonAI.getEnemyTypes();
    
    std::cout << "✓ Dungeon AI initialized with " << AVAILABLE_MANA << " mana\n";
    std::cout << "✓ Available enemy types: " << enemyTypes.size() << "\n";
    for (size_t i = 0; i < enemyTypes.size(); ++i) {
        std::cout << "  - " << enemyTypes[i].name << " (Mana: " << enemyTypes[i].manaCost << ")\n";
    }
    std::cout << "✓ Neural network: 10 inputs → [16, 8] hidden layers → "
              << enemyTypes.size() << " outputs\n\n";

    // ========================================================================
    // STEP 2: SIMULATE PLAYER STATISTICS AND GAME SCENARIOS
    // ========================================================================
if (RUN_SCENARIOS) {
    std::cout << "=" << std::string(60, '=') << "\n";
    std::cout << "SCENARIO 1: Weak Player (Low Damage, Low Resistance)\n";
    std::cout << "=" << std::string(60, '=') << "\n\n";

    // Scenario 1: Weak player doing little damage.
    // Damage taken is now simulated from AI spawns (not preset).
    double timeSpent1 = 245.0;  // seconds
    double playerMelee1 = 1.5;
    double playerRange1 = 1.5;
    double playerHealth1 = 50.0;
    double playerSpeed1 = 1.5;
    double playerDefense1 = 0.5;
    double availMana1 = 10.0;

    std::cout << "Player Statistics:\n";
    std::cout << "  Physical Damage Taken: simulated after spawn\n";
    std::cout << "  Magic Damage Taken: simulated after spawn\n";
    std::cout << "  Time Survived: " << timeSpent1 << " seconds\n";
    std::cout << "  Weapon Melee Damage: " << playerMelee1 << "\n";
    std::cout << "  Weapon Range Damage: " << playerRange1 << "\n";
    std::cout << "  Health: " << playerHealth1 << "\n";
    std::cout << "  Speed: " << playerSpeed1 << "\n";
    std::cout << "  Defense: " << playerDefense1 << "\n";
    std::cout << "  Available Mana: " << availMana1 << "\n\n";

    // Get AI spawning decision
    std::vector<int> spawns1 = dungeonAI.decideEnemySpawns(
        0.0, 0.0, timeSpent1,
        playerMelee1, playerRange1,
        playerHealth1, playerSpeed1, playerDefense1,
        0.0,
        availMana1
    );

    const CombatDamageResult combat1 = simulateDamage(spawns1, dungeonAI.getEnemyTypes(), playerDefense1, playerSpeed1);
    const double runDamageTaken1 = combat1.totalDamage;
    const double physicalDmg1 = combat1.totalPhysicalDamage;
    const double magicDmg1 = combat1.totalMagicDamage;

    std::cout << "AI Decision:\n";
    dungeonAI.printSpawningStrategy(spawns1);
    std::cout << "Simulated Damage Taken (feedback): " << runDamageTaken1
              << " [Physical: " << physicalDmg1 << ", Magic: " << magicDmg1 << "]\n";

    // Calculate expected outcome
    double reward1 = dungeonAI.calculateReward(
        timeSpent1, 
        physicalDmg1 + magicDmg1, 
        calculateManaUsed(spawns1, enemyTypes)
    );
    std::cout << "\nExpected Reward: " << std::fixed << std::setprecision(4) << reward1 << "\n";

    // Learn immediately from this interaction (player is still alive)
    dungeonAI.learnFromInteraction(
        physicalDmg1, magicDmg1, timeSpent1,
        playerMelee1, playerRange1,
        playerHealth1, playerSpeed1, playerDefense1,
        0.0,
        availMana1,
        spawns1,
        combat1.damageByEnemyType,
        reward1,
        false
    );

    // ========================================================================
    // SCENARIO 2: STRONG MELEE PLAYER
    // ========================================================================
    std::cout << "\n" << "=" << std::string(60, '=') << "\n";
    std::cout << "SCENARIO 2: Strong Melee Player (High Melee, Low Magic Weapon)\n";
    std::cout << "=" << std::string(60, '=') << "\n\n";

    double timeSpent2 = 120.0;
    double playerMelee2 = 6.0;    // STRONG MELEE
    double playerRange2 = 1.0;     // WEAK RANGED
    double playerHealth2 = 50.0;
    double playerSpeed2 = 1.0;
    double playerDefense2 = 2.0;
    double availMana2 = 10.0;

    std::cout << "Player Statistics:\n";
    std::cout << "  Physical Damage Taken: simulated after spawn\n";
    std::cout << "  Magic Damage Taken: simulated after spawn\n";
    std::cout << "  Time Survived: " << timeSpent2 << " seconds\n";
    std::cout << "  Weapon Melee Damage: " << playerMelee2 << " ← STRONG\n";
    std::cout << "  Weapon Range Damage: " << playerRange2 << " ← WEAK\n";
    std::cout << "  Health: " << playerHealth2 << "\n";
    std::cout << "  Speed: " << playerSpeed2 << "\n";
    std::cout << "  Defense: " << playerDefense2 << "\n";
    std::cout << "  Available Mana: " << availMana2 << "\n\n";

    // AI should adapt toward configured enemy types that counter strong melee builds.
    std::vector<int> spawns2 = dungeonAI.decideEnemySpawns(
        0.0, 0.0, timeSpent2,
        playerMelee2, playerRange2,
        playerHealth2, playerSpeed2, playerDefense2,
        0.0,
        availMana2
    );

    const CombatDamageResult combat2 = simulateDamage(spawns2, dungeonAI.getEnemyTypes(), playerDefense2, playerSpeed2);
    const double runDamageTaken2 = combat2.totalDamage;
    const double physicalDmg2 = combat2.totalPhysicalDamage;
    const double magicDmg2 = combat2.totalMagicDamage;

    std::cout << "AI Decision:\n";
    std::cout << "Note: AI uses DungeonAI enemy definitions to counter player\'s strong melee build\n\n";
    dungeonAI.printSpawningStrategy(spawns2);
    std::cout << "Simulated Damage Taken (feedback): " << runDamageTaken2
              << " [Physical: " << physicalDmg2 << ", Magic: " << magicDmg2 << "]\n";

    double reward2 = dungeonAI.calculateReward(
        timeSpent2,
        physicalDmg2 + magicDmg2,
        calculateManaUsed(spawns2, enemyTypes)
    );
    std::cout << "\nExpected Reward: " << std::fixed << std::setprecision(4) << reward2 << "\n";

    dungeonAI.learnFromInteraction(
        physicalDmg2, magicDmg2, timeSpent2,
        playerMelee2, playerRange2,
        playerHealth2, playerSpeed2, playerDefense2,
        0.0,
        availMana2,
        spawns2,
        combat2.damageByEnemyType,
        reward2,
        false
    );

    // ========================================================================
    // SCENARIO 3: STRONG RANGED PLAYER
    // ========================================================================
    std::cout << "\n" << "=" << std::string(60, '=') << "\n";
    std::cout << "SCENARIO 3: Strong Ranged Player (Low Melee, High Ranged)\n";
    std::cout << "=" << std::string(60, '=') << "\n\n";

    double timeSpent3 = 130.0;
    double playerMelee3 = 1.0;     // WEAK MELEE
    double playerRange3 = 6.0;    // STRONG RANGED
    double playerHealth3 = 50.0;
    double playerSpeed3 = 2.0;
    double playerDefense3 = 0.5;
    double availMana3 = 10.0;

    std::cout << "Player Statistics:\n";
    std::cout << "  Physical Damage Taken: simulated after spawn\n";
    std::cout << "  Magic Damage Taken: simulated after spawn\n";
    std::cout << "  Time Survived: " << timeSpent3 << " seconds\n";
    std::cout << "  Weapon Melee Damage: " << playerMelee3 << " ← WEAK\n";
    std::cout << "  Weapon Range Damage: " << playerRange3 << " ← STRONG\n";
    std::cout << "  Health: " << playerHealth3 << "\n";
    std::cout << "  Speed: " << playerSpeed3 << "\n";
    std::cout << "  Defense: " << playerDefense3 << "\n";
    std::cout << "  Available Mana: " << availMana3 << "\n\n";

    // AI should adapt toward configured enemy types that counter strong ranged builds.
    std::vector<int> spawns3 = dungeonAI.decideEnemySpawns(
        0.0, 0.0, timeSpent3,
        playerMelee3, playerRange3,
        playerHealth3, playerSpeed3, playerDefense3,
        0.0,
        availMana3
    );

    const CombatDamageResult combat3 = simulateDamage(spawns3, dungeonAI.getEnemyTypes(), playerDefense3, playerSpeed3);
    const double runDamageTaken3 = combat3.totalDamage;
    const double physicalDmg3 = combat3.totalPhysicalDamage;
    const double magicDmg3 = combat3.totalMagicDamage;

    std::cout << "AI Decision:\n";
    std::cout << "Note: AI uses DungeonAI enemy definitions to counter player\'s strong ranged build\n\n";
    dungeonAI.printSpawningStrategy(spawns3);
    std::cout << "Simulated Damage Taken (feedback): " << runDamageTaken3
              << " [Physical: " << physicalDmg3 << ", Magic: " << magicDmg3 << "]\n";

    double reward3 = dungeonAI.calculateReward(
        timeSpent3,
        physicalDmg3 + magicDmg3,
        calculateManaUsed(spawns3, enemyTypes)
    );
    std::cout << "\nExpected Reward: " << std::fixed << std::setprecision(4) << reward3 << "\n";

    dungeonAI.learnFromInteraction(
        physicalDmg3, magicDmg3, timeSpent3,
        playerMelee3, playerRange3,
        playerHealth3, playerSpeed3, playerDefense3,
        0.0,
        availMana3,
        spawns3,
        combat3.damageByEnemyType,
        reward3,
        false
    );

    // ========================================================================
    // SCENARIO 4: BALANCED BUT WEAK PLAYER
    // ========================================================================
    std::cout << "\n" << "=" << std::string(60, '=') << "\n";
    std::cout << "SCENARIO 4: Balanced but Weak Player (Low All Stats)\n";
    std::cout << "=" << std::string(60, '=') << "\n\n";

    double timeSpent4 = 140.0;
    double playerMelee4 = 5.0;    // Balanced
    double playerRange4 = 3.5;     // Balanced
    double playerHealth4 = 50.0;
    double playerSpeed4 = 1.5;
    double playerDefense4 = 0.5;
    double availMana4 = 10.0;

    std::cout << "Player Statistics:\n";
    std::cout << "  Physical Damage Taken: simulated after spawn\n";
    std::cout << "  Magic Damage Taken: simulated after spawn\n";
    std::cout << "  Time Survived: " << timeSpent4 << " seconds\n";
    std::cout << "  Weapon Melee Damage: " << playerMelee4 << " (Balanced)\n";
    std::cout << "  Weapon Range Damage: " << playerRange4 << " (Balanced)\n";
    std::cout << "  Health: " << playerHealth4 << "\n";
    std::cout << "  Speed: " << playerSpeed4 << "\n";
    std::cout << "  Defense: " << playerDefense4 << "\n";
    std::cout << "  Available Mana: " << availMana4 << "\n\n";

    std::vector<int> spawns4 = dungeonAI.decideEnemySpawns(
        0.0, 0.0, timeSpent4,
        playerMelee4, playerRange4,
        playerHealth4, playerSpeed4, playerDefense4,
        0.0,
        availMana4
    );

    const CombatDamageResult combat4 = simulateDamage(spawns4, dungeonAI.getEnemyTypes(), playerDefense4, playerSpeed4);
    const double runDamageTaken4 = combat4.totalDamage;
    const double physicalDmg4 = combat4.totalPhysicalDamage;
    const double magicDmg4 = combat4.totalMagicDamage;

    std::cout << "AI Decision:\n";
    dungeonAI.printSpawningStrategy(spawns4);
    std::cout << "Simulated Damage Taken (feedback): " << runDamageTaken4
              << " [Physical: " << physicalDmg4 << ", Magic: " << magicDmg4 << "]\n";

    double reward4 = dungeonAI.calculateReward(
        timeSpent4,
        physicalDmg4 + magicDmg4,
        calculateManaUsed(spawns4, enemyTypes)
    );
    std::cout << "\nExpected Reward: " << std::fixed << std::setprecision(4) << reward4 << "\n";

    dungeonAI.learnFromInteraction(
        physicalDmg4, magicDmg4, timeSpent4,
        playerMelee4, playerRange4,
        playerHealth4, playerSpeed4, playerDefense4,
        0.0,
        availMana4,
        spawns4,
        combat4.damageByEnemyType,
        reward4,
        false
    );
}

    // =========================================================================
    // STEP 3: ONLINE LEARNING + RESET ON DEATH
    // =========================================================================
    std::cout << "\n" << "=" << std::string(60, '=') << "\n";
    std::cout << "ONLINE LEARNING PHASE\n";
    std::cout << "=" << std::string(60, '=') << "\n\n";

    std::cout << "AI learned from each interaction above in real-time.\n";
    std::cout << "Current episode memory size: " << dungeonAI.getEpisodeMemorySize() << "\n\n";

    // Show analysis before the demonstration death/reset so data is visible.
    std::cout << "\n" << "=" << std::string(60, '=') << "\n";
    std::cout << "AI PERFORMANCE ANALYSIS (PRE-RESET)\n";
    std::cout << "=" << std::string(60, '=') << "\n";
    dungeonAI.printAIAnalysis();
    std::cout << "\n";

    std::cout << "Simulating player death with final score...\n";
    dungeonAI.learnFromInteraction(
        120.0, 110.0, 210.0,
        18.0, 16.0,
        95.0, 11.0, 14.0,
        0.0,
        150.0,
        {1, 1, 1, 1},
        {},
        72.0,
        true
    );

    std::cout << "Episode memory after death reset: " << dungeonAI.getEpisodeMemorySize() << "\n\n";

    // =========================================================================
    // STEP 4: DISPLAY ANALYSIS AFTER RESET
    // =========================================================================
    std::cout << "\n" << "=" << std::string(60, '=') << "\n";
    std::cout << "AI PERFORMANCE ANALYSIS (POST-RESET)\n";
    std::cout << "=" << std::string(60, '=') << "\n";

    dungeonAI.printAIAnalysis();

    // =========================================================================
    // STEP 5: POPUP-BASED USER INTERACTION
    // =========================================================================
    std::cout << "\n" << "=" << std::string(60, '=') << "\n";
    std::cout << "INTERACTIVE POPUP MODE\n";
    std::cout << "=" << std::string(60, '=') << "\n\n";

    std::cout << "A mode popup will open: Manual Run or Auto Runs Until Player Dies.\n";
    std::cout << "A difficulty popup now appears first: Easy resets AI memory, Hard keeps memory.\n";
    std::cout << "Auto-run base stats are configurable in getAutoRunConfig() near the top of this file.\n\n";

    while (true) {
        DifficultyMode difficulty = promptDifficultyModePopup();
        if (difficulty == DIFFICULTY_CANCEL) {
            std::cout << "Difficulty selection cancelled. Exiting interactive mode.\n\n";
            break;
        }

        if (difficulty == DIFFICULTY_EASY) {
            dungeonAI.setKeepMemoryOnDeath(false);
            dungeonAI.resetAllMemory();
            std::cout << "Difficulty: Easy (AI reset to scratch for this run selection).\n";
        } else {
            dungeonAI.setKeepMemoryOnDeath(true);
            dungeonAI.resetAllMemory();
            const int loadedDecisions = dungeonAI.loadMemoryFromFileAndTrain(5);
            std::cout << "Difficulty: Hard (AI memory persists across runs and deaths).\n";
            std::cout << "Loaded " << loadedDecisions << " historical decisions from "
                      << dungeonAI.getMemoryFilePath() << "\n";
        }

        RunMode mode = promptRunModePopup();
        if (mode == RUN_MODE_CANCEL) {
            std::cout << "Run mode selection cancelled. Exiting interactive mode.\n\n";
            break;
        }

        if (mode == RUN_MODE_RESET) {
            const bool confirmed = confirmResetTrainingDataPopup();
            if (!confirmed) {
                std::cout << "Training reset cancelled.\n\n";
                continue;
            }

            if (dungeonAI.resetPersistentTrainingData()) {
                std::cout << "Training data reset complete (memory + "
                          << dungeonAI.getMemoryFilePath() << ").\n\n";
            } else {
                std::cout << "Failed to reset persistent training data file: "
                          << dungeonAI.getMemoryFilePath() << "\n\n";
            }
            continue;
        }

        if (mode == RUN_MODE_MANUAL) {
            struct ManualMetricRow {
                int runNumber;
                int manaUsed;
                double playerHealth;
                double playerHealing;
                double damageToPlayer;
                double aiScorePercent;
                double enemyCount;
                std::string enemyTypeCounts;
                double playerSpeed;
                double playerDefense;
            };

            std::vector<RunScores> manualRunScores;
            std::vector<ManualMetricRow> manualMetricRows;
            const std::string manualCsvPath = "manual_metrics.csv";
            const int manualGameNumber = getNextAutoRunGameNumber(manualCsvPath);
            bool manualCsvWriteFailed = false;
            bool manualModeAborted = false;
            const double manualMaxHealth = 50.0;
            double currentManualHealth = manualMaxHealth;
            double previousPhysicalDamage = 0.0;
            double previousMagicDamage = 0.0;
            double previousHealingReceived = 0.0;
            const double manualDeathThreshold = 1.0;

            const AutoRunConfig manualBaseCfg = getAutoRunConfig();
            UserInteractionInput manualDefaults = {};
            manualDefaults.timeSurvived = manualBaseCfg.baseTimeSurvived;
            manualDefaults.physicalDamage = 0.0;
            manualDefaults.magicDamage = 0.0;
            manualDefaults.meleeDamage = manualBaseCfg.baseMeleeDamage;
            manualDefaults.rangeDamage = manualBaseCfg.baseRangeDamage;
            manualDefaults.health = manualBaseCfg.baseHealth;
            manualDefaults.speed = manualBaseCfg.baseSpeed;
            manualDefaults.defense = manualBaseCfg.baseDefense;
            manualDefaults.healingReceived = 0.0;
            manualDefaults.dungeonMana = manualBaseCfg.baseDungeonMana;
            manualDefaults.playerDied = false;
            manualDefaults.endManualRunRequested = false;
            double manualCurrentMana = manualBaseCfg.baseDungeonMana;

            auto exportManualMetrics = [&]() {
                for (size_t idx = 0; idx < manualMetricRows.size(); ++idx) {
                    const auto& row = manualMetricRows[idx];
                    if (!appendAutoRunMetricRowToExcelCsv(
                        manualCsvPath,
                        manualGameNumber,
                        row.runNumber,
                        static_cast<double>(row.manaUsed),
                        row.playerHealth,
                        row.playerHealing,
                        row.damageToPlayer,
                        row.aiScorePercent,
                        row.enemyCount,
                        row.enemyTypeCounts,
                        row.playerSpeed,
                        row.playerDefense
                    )) {
                        manualCsvWriteFailed = true;
                    }
                }
            };

            std::cout << "Exporting manual metrics to " << manualCsvPath
                      << " (Game " << manualGameNumber << ")\n";

            int manualRunNumber = 0;
            while (true) {
                manualDefaults.dungeonMana = manualCurrentMana;
                UserInteractionInput userInput = manualDefaults;
                bool submitted = showInteractionInputPopup(userInput, false, true, currentManualHealth);
                if (!submitted) {
                    manualModeAborted = true;
                    std::cout << "Manual input cancelled. Manual session ended without export.\n\n";
                    break;
                }

                if (userInput.endManualRunRequested) {
                    if (!manualMetricRows.empty()) {
                        exportManualMetrics();
                        showAutoRunSummaryWindow(buildAutoRunSummaryText(manualRunScores));
                        std::cout << "Manual run ended early. Total runs: " << manualRunScores.size() << "\n";
                        if (manualCsvWriteFailed) {
                            std::cout << "Warning: one or more rows could not be written to " << manualCsvPath << "\n";
                        } else {
                            std::cout << "CSV export updated: " << manualCsvPath << "\n";
                            launchPythonMetricsGraphs(manualCsvPath, manualGameNumber);
                        }
                    } else {
                        std::cout << "Manual run ended early before any rounds were recorded.\n";
                    }
                    std::cout << "Current episode memory size: " << dungeonAI.getEpisodeMemorySize() << "\n\n";
                    break;
                }

                // Persist manual inputs as defaults for the next round.
                manualDefaults.timeSurvived = userInput.timeSurvived;
                manualDefaults.meleeDamage = userInput.meleeDamage;
                manualDefaults.rangeDamage = userInput.rangeDamage;
                manualDefaults.speed = userInput.speed;
                manualDefaults.defense = userInput.defense;

                manualRunNumber++;

                // In manual mode, combat feedback is simulated by AI each round.
                // User-provided physical/magic damage and death are ignored.
                userInput.health = currentManualHealth;
                userInput.physicalDamage = previousPhysicalDamage;
                userInput.magicDamage = previousMagicDamage;
                userInput.healingReceived = previousHealingReceived;
                userInput.playerDied = false;

                // Manual mode mana is system-managed using auto-run progression.
                userInput.dungeonMana = manualCurrentMana;

                std::vector<int> userSpawns = dungeonAI.decideEnemySpawns(
                    userInput.physicalDamage,
                    userInput.magicDamage,
                    userInput.timeSurvived,
                    userInput.meleeDamage,
                    userInput.rangeDamage,
                    userInput.health,
                    userInput.speed,
                    userInput.defense,
                    userInput.healingReceived,
                    userInput.dungeonMana
                );

                const int manaUsed = calculateManaUsed(userSpawns, enemyTypes);

                const CombatDamageResult runCombat = simulateDamage(
                    userSpawns,
                    dungeonAI.getEnemyTypes(),
                    userInput.defense,
                    userInput.speed
                );

                const double runDamageTaken = runCombat.totalDamage;
                currentManualHealth = std::max(0.0, currentManualHealth - runDamageTaken);

                int healProcCount = 0;
                const double healedAmount = simulateEndOfRoundHealing(
                    userSpawns,
                    enemyTypes,
                    currentManualHealth,
                    manualMaxHealth,
                    healProcCount
                );
                currentManualHealth = std::min(manualMaxHealth, currentManualHealth + healedAmount);

                const double effectiveDamage = std::max(0.0, runDamageTaken - healedAmount);
                const double totalRawDamage = std::max(1e-9, runCombat.totalPhysicalDamage + runCombat.totalMagicDamage);
                const double physicalRatio = std::max(0.0, runCombat.totalPhysicalDamage) / totalRawDamage;
                const double magicRatio = std::max(0.0, runCombat.totalMagicDamage) / totalRawDamage;
                userInput.physicalDamage = effectiveDamage * physicalRatio;
                userInput.magicDamage = effectiveDamage * magicRatio;
                userInput.healingReceived = healedAmount;
                userInput.health = currentManualHealth;
                userInput.playerDied = (currentManualHealth <= manualDeathThreshold);

                previousPhysicalDamage = userInput.physicalDamage;
                previousMagicDamage = userInput.magicDamage;
                previousHealingReceived = userInput.healingReceived;

                const double aiLearningScore = dungeonAI.calculateReward(
                    userInput.timeSurvived,
                    userInput.physicalDamage + userInput.magicDamage,
                    manaUsed
                );
                const double playerScorePercent = calculatePlayerScorePercent(userInput);
                const double damageToPlayer = userInput.physicalDamage + userInput.magicDamage;
                const double enemyCount = static_cast<double>(std::accumulate(userSpawns.begin(), userSpawns.end(), 0));
                const std::string enemyTypeCountsCsvText = buildSpawnCsvCountsText(userSpawns, enemyTypes);

                std::cout << "AI Decision for Your Input (Run " << manualRunNumber << "):\n";
                dungeonAI.printSpawningStrategy(userSpawns);
                std::cout << "Simulated Damage Taken: " << std::fixed << std::setprecision(2) << runDamageTaken
                          << " [Physical: " << runCombat.totalPhysicalDamage
                          << ", Magic: " << runCombat.totalMagicDamage << "]\n";
                std::cout << "Simulated Healing: " << userInput.healingReceived
                          << " (procs=" << healProcCount << ")\n";
                std::cout << "End Health: " << userInput.health
                          << " | Died: " << (userInput.playerDied ? "Yes" : "No") << "\n";
                std::cout << "Player Score (auto): " << std::fixed << std::setprecision(2)
                          << playerScorePercent << "/100\n";
                std::cout << "AI Score: " << (aiLearningScore * 100.0) << "/100\n";

                dungeonAI.learnFromInteraction(
                    userInput.physicalDamage,
                    userInput.magicDamage,
                    userInput.timeSurvived,
                    userInput.meleeDamage,
                    userInput.rangeDamage,
                    userInput.health,
                    userInput.speed,
                    userInput.defense,
                    userInput.healingReceived,
                    userInput.dungeonMana,
                    userSpawns,
                    runCombat.damageByEnemyType,
                    aiLearningScore,
                    userInput.playerDied,
                    runCombat.totalPhysicalDamage,
                    runCombat.totalMagicDamage
                );

                manualRunScores.push_back({
                    manualRunNumber,
                    aiLearningScore * 100.0,
                    playerScorePercent,
                    userInput.playerDied
                });

                manualMetricRows.push_back({
                    manualRunNumber,
                    manaUsed,
                    userInput.health,
                    userInput.healingReceived,
                    damageToPlayer,
                    aiLearningScore * 100.0,
                    enemyCount,
                    enemyTypeCountsCsvText,
                    userInput.speed,
                    userInput.defense
                });

                if (userInput.playerDied) {
                    exportManualMetrics();

                    showAutoRunSummaryWindow(buildAutoRunSummaryText(manualRunScores));
                    std::cout << "Manual run complete. Total runs: " << manualRunScores.size() << "\n";
                    if (manualCsvWriteFailed) {
                        std::cout << "Warning: one or more rows could not be written to " << manualCsvPath << "\n";
                    } else {
                        std::cout << "CSV export updated: " << manualCsvPath << "\n";
                        launchPythonMetricsGraphs(manualCsvPath, manualGameNumber);
                    }
                    std::cout << "Current episode memory size: " << dungeonAI.getEpisodeMemorySize() << "\n\n";
                    break;
                }

                manualCurrentMana += getRandomInRange(manualBaseCfg.manaIncreasePerRun);

                std::cout << "Player is alive. Starting next manual round immediately...\n\n";
            }

            if (manualModeAborted) {
                continue;
            }
        } else {
            int gamesToRun = 1;
            AutoRunProfile profile = promptAutoRunProfilePopup(gamesToRun);
            if (profile == AUTO_PROFILE_CANCEL) {
                std::cout << "Auto run profile selection cancelled.\n\n";
                continue;
            }

            if (gamesToRun <= 0) {
                gamesToRun = 1;
            }

            std::cout << "Auto run profile selected: ";
            if (profile == AUTO_PROFILE_SCENARIO_1) std::cout << "Scenario 1";
            else if (profile == AUTO_PROFILE_SCENARIO_2) std::cout << "Scenario 2";
            else if (profile == AUTO_PROFILE_SCENARIO_3) std::cout << "Scenario 3";
            else if (profile == AUTO_PROFILE_SCENARIO_4) std::cout << "Scenario 4";
            else if (profile == AUTO_PROFILE_OVERPOWERED) std::cout << "Overpowered";
            else std::cout << "Complete Random";
            std::cout << " | Games: " << gamesToRun << "\n";

            const std::string autoRunCsvPath = "auto_run_metrics.csv";
            bool autoBatchHasSuccessfulExport = false;
            int autoBatchFirstGameNumber = -1;
            int autoBatchLastGameNumber = -1;

            for (int gameBatchIndex = 1; gameBatchIndex <= gamesToRun; ++gameBatchIndex) {
                AutoRunConfig autoCfg = getAutoRunConfig();
                applyAutoRunProfile(autoCfg, profile);

                std::vector<RunScores> autoRunScores;
                std::vector<AutoRunRoundLog> autoRunRoundLogs;
                std::vector<double> healthHistory;
                std::vector<double> manaHistory;
                std::vector<double> healingHistory;
                std::vector<double> damageToPlayerHistory;
                std::vector<double> enemyCountHistory;
                std::vector<std::vector<double>> enemyTypeCountsOverTime(enemyTypes.size());

                const int autoRunGameNumber = getNextAutoRunGameNumber(autoRunCsvPath);
                bool csvWriteFailed = false;
                std::cout << "Starting auto game " << gameBatchIndex << "/" << gamesToRun << "\n";
                std::cout << "Exporting auto-run metrics to " << autoRunCsvPath
                          << " (Game " << autoRunGameNumber << ")\n";

                double currentHealth = autoCfg.baseHealth;
                double previousPhysicalDamage = 0.0;
                double previousMagicDamage = 0.0;
                double previousHealingReceived = 0.0;
                bool died = false;

                for (int run = 1; run <= autoCfg.maxRuns; run++) {
                    UserInteractionInput autoInput = buildAutoRunInput(
                        autoCfg,
                        run,
                        currentHealth,
                        previousPhysicalDamage,
                        previousMagicDamage,
                        previousHealingReceived
                    );

                    std::vector<int> autoSpawns = dungeonAI.decideEnemySpawns(
                        autoInput.physicalDamage,
                        autoInput.magicDamage,
                        autoInput.timeSurvived,
                        autoInput.meleeDamage,
                        autoInput.rangeDamage,
                        autoInput.health,
                        autoInput.speed,
                        autoInput.defense,
                        autoInput.healingReceived,
                        autoInput.dungeonMana
                    );

                    const int manaUsed = calculateManaUsed(autoSpawns, enemyTypes);

                    const CombatDamageResult runCombat = simulateDamage(
                        autoSpawns,
                        dungeonAI.getEnemyTypes(),
                        autoInput.defense,
                        autoInput.speed
                    );
                    const double runDamageTaken = runCombat.totalDamage;
                    autoInput.physicalDamage = runCombat.totalPhysicalDamage;
                    autoInput.magicDamage = runCombat.totalMagicDamage;

                    currentHealth = std::max(0.0, currentHealth - (runDamageTaken));

                    int healProcCount = 0;
                    const double healedAmount = simulateEndOfRoundHealing(
                        autoSpawns,
                        enemyTypes,
                        currentHealth,
                        autoCfg.baseHealth,
                        healProcCount
                    );
                    currentHealth = std::min(autoCfg.baseHealth, currentHealth + healedAmount);

                    const double effectiveDamage = std::max(0.0, runDamageTaken - healedAmount);
                    const double totalRawDamage = std::max(1e-9, runCombat.totalPhysicalDamage + runCombat.totalMagicDamage);
                    const double physicalRatio = std::max(0.0, runCombat.totalPhysicalDamage) / totalRawDamage;
                    const double magicRatio = std::max(0.0, runCombat.totalMagicDamage) / totalRawDamage;
                    autoInput.physicalDamage = effectiveDamage * physicalRatio;
                    autoInput.magicDamage = effectiveDamage * magicRatio;
                    autoInput.healingReceived = healedAmount;

                    const double aiLearningScore = dungeonAI.calculateReward(
                        autoInput.timeSurvived,
                        autoInput.physicalDamage + autoInput.magicDamage,
                        manaUsed
                    );

                    previousPhysicalDamage = autoInput.physicalDamage;
                    previousMagicDamage = autoInput.magicDamage;
                    previousHealingReceived = autoInput.healingReceived;

                    bool recoveredAtRound10 = false;
                    if (currentHealth > autoCfg.deathHealthThreshold && (run % 10 == 0)) {
                        currentHealth = 50.0;
                        recoveredAtRound10 = true;
                    }

                    if (run % 5 == 0) {
                        autoCfg.baseSpeed += 0.5;
                        autoCfg.baseDefense += 0.5;
                    }

                    autoInput.health = currentHealth;

                    healthHistory.push_back(currentHealth);
                    manaHistory.push_back(static_cast<double>(manaUsed));
                    healingHistory.push_back(healedAmount);
                    damageToPlayerHistory.push_back(runDamageTaken);
                    enemyCountHistory.push_back(static_cast<double>(std::accumulate(autoSpawns.begin(), autoSpawns.end(), 0)));
                    const std::string enemyTypeCountsCsvText = buildSpawnCsvCountsText(autoSpawns, enemyTypes);

                    if (!appendAutoRunMetricRowToExcelCsv(
                        autoRunCsvPath,
                        autoRunGameNumber,
                        run,
                        static_cast<double>(manaUsed),
                        currentHealth,
                        healedAmount,
                        runDamageTaken,
                        aiLearningScore * 100.0,
                        enemyCountHistory.back(),
                        enemyTypeCountsCsvText,
                        autoInput.speed,
                        autoInput.defense
                    )) {
                        csvWriteFailed = true;
                    }

                    for (size_t typeIndex = 0; typeIndex < enemyTypes.size(); ++typeIndex) {
                        const double countForType = (typeIndex < autoSpawns.size()) ? static_cast<double>(std::max(0, autoSpawns[typeIndex])) : 0.0;
                        enemyTypeCountsOverTime[typeIndex].push_back(countForType);
                    }

                    autoInput.playerDied = (currentHealth <= autoCfg.deathHealthThreshold);

                    const double playerScorePercent = calculatePlayerScorePercent(autoInput);

                    dungeonAI.learnFromInteraction(
                        autoInput.physicalDamage,
                        autoInput.magicDamage,
                        autoInput.timeSurvived,
                        autoInput.meleeDamage,
                        autoInput.rangeDamage,
                        autoInput.health,
                        autoInput.speed,
                        autoInput.defense,
                        autoInput.healingReceived,
                        autoInput.dungeonMana,
                        autoSpawns,
                        runCombat.damageByEnemyType,
                        aiLearningScore,
                        autoInput.playerDied,
                        runCombat.totalPhysicalDamage,
                        runCombat.totalMagicDamage
                    );

                    autoRunScores.push_back({
                        run,
                        aiLearningScore * 100.0,
                        playerScorePercent,
                        autoInput.playerDied
                    });

                    autoRunRoundLogs.push_back({
                        run,
                        autoSpawns,
                        manaUsed,
                        runDamageTaken,
                        healedAmount,
                        healProcCount,
                        aiLearningScore * 100.0,
                        currentHealth,
                        recoveredAtRound10,
                        autoInput.playerDied
                    });

                    if (autoInput.playerDied) {
                        died = true;
                        break;
                    }
                }

                if (!died && !autoRunScores.empty()) {
                    autoRunScores.back().playerDied = true;
                }

                if (gamesToRun <= 1) {
                    showAutoRunSummaryWindow(buildAutoRunSummaryText(autoRunScores));
                    showAutoRunSummaryWindow(buildAutoRunRoundLogText(autoRunRoundLogs, enemyTypes));
                    if (!autoRunScores.empty() && autoRunScores.back().playerDied) {
                        showAutoRunGraphWindow(buildAutoRunLineGraphText(
                            manaHistory,
                            healthHistory,
                            healingHistory,
                            damageToPlayerHistory,
                            enemyCountHistory
                        ));
                    }
                }
                std::cout << "Auto run game " << gameBatchIndex << " complete. Total runs: " << autoRunScores.size() << "\n";
                if (csvWriteFailed) {
                    std::cout << "Warning: one or more rows could not be written to " << autoRunCsvPath << "\n";
                } else {
                    std::cout << "CSV export updated: " << autoRunCsvPath << "\n";
                    if (gamesToRun <= 1) {
                        launchPythonMetricsGraphs(autoRunCsvPath, autoRunGameNumber);
                    } else {
                        autoBatchHasSuccessfulExport = true;
                        if (autoBatchFirstGameNumber < 0) {
                            autoBatchFirstGameNumber = autoRunGameNumber;
                        }
                        autoBatchLastGameNumber = autoRunGameNumber;
                    }
                }
            }

            if (gamesToRun > 1) {
                std::cout << "Skipped follow-up auto popups for multi-game batch (" << gamesToRun << " games).\n";
                if (autoBatchHasSuccessfulExport && autoBatchFirstGameNumber > 0 && autoBatchLastGameNumber > 0) {
                    std::cout << "Launching combined graphs for games "
                              << autoBatchFirstGameNumber << " to " << autoBatchLastGameNumber
                              << " from this batch...\n";
                    launchPythonMetricsGraphs(autoRunCsvPath, autoBatchFirstGameNumber, autoBatchLastGameNumber);
                }
            }
            std::cout << "Auto batch complete. Base auto-run stats are in getAutoRunConfig() in dungeon_main.cpp\n\n";
        }

#ifdef _WIN32
        int continueChoice = MessageBoxA(
            nullptr,
            "Choose another run mode?",
            "Continue",
            MB_YESNO | MB_ICONQUESTION
        );
        if (continueChoice != IDYES) {
            std::cout << "User ended interactive mode.\n\n";
            break;
        }
#else
        char again = 'n';
        std::cout << "Choose another run mode? (y/n): ";
        std::cin >> again;
        if (again != 'y' && again != 'Y') {
            std::cout << "User ended interactive mode.\n\n";
            break;
        }
#endif
    }

    std::cout << "\n\nTHE END\n";
    return 0;
}

/*
═══════════════════════════════════════════════════════════════
DUNGEON MASTER - SYSTEM OVERVIEW
═══════════════════════════════════════════════════════════════

INPUT FEATURES (10):
  1. Physical Damage Done to Player (0-200+)
  2. Magic Damage Done to Player (0-200+)
  3. Time Player Took (0-300+ seconds)
  4. Player Weapon Melee Damage (0-30+)
  5. Player Weapon Range Damage (0-30+)
    6. Player Health (0-200+)
    7. Player Speed (0-20+)
    8. Player Defense (0-50+)
    9. Healing Received from Enemies (0-200+)
    10. Dungeon Mana Available (0-500+)

OUTPUT (Enemy Types from DungeonAI):
    • Count and stats come from `DungeonAI::initializeEnemyTypes()`.
    • Network output size matches configured enemy type count.

NEURAL NETWORK:
        Architecture: [10] → [16] → [8] → [N]
    - 10 input neurons: Player stat features + healing received
  - 16 neurons: First hidden layer (learns patterns)
  - 8 neurons: Second hidden layer (combines patterns)
    - N output neurons: Spawn priority for each configured enemy type

TRAINING ALGORITHM:
  1. Forward Pass: Compute network output for given player stats
  2. Calculate Expected Damage: Get total damage from spawned enemies
  3. Compare to Goals: Did we maximize time + damage with mana?
  4. Backward Pass: Adjust weights to improve decisions
  5. Learn: Over time, network learns optimal spawning strategies

REWARD FUNCTION:
  Reward = (0.4 × Time Score) + (0.5 × Damage Score) + (0.1 × Efficiency)
  - Prioritizes damage (highest impact on challenge)
  - Rewards long survival times (engaging gameplay)
  - Considers mana efficiency (resource management)

═══════════════════════════════════════════════════════════════
*/
