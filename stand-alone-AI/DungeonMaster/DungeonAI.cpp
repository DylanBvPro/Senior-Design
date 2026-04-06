#include "DungeonAI.h"
#include <iostream>
#include <algorithm>
#include <cmath>
#include <random>
#include <fstream>
#include <sstream>
#include <iomanip>

// Constructor: Create dungeon AI system
DungeonAI::DungeonAI(double availableMana) 
        : networkShape({10, 16, 8, static_cast<int>(SKELETON_TYPE_COUNT)}),
            defaultLearningRate(0.1),
            aiNetwork(networkShape, defaultLearningRate),  // Neural network: 10 inputs, 2 hidden layers, N outputs (one per enemy type)
    dungeonManaAvailable(availableMana),
    keepMemoryOnDeath(false),
    memoryFilePath("hard_memory.csv")
{
    initializeEnemyTypes();
}

static std::string joinInts(const std::vector<int>& values) {
    std::ostringstream out;
    for (size_t i = 0; i < values.size(); ++i) {
        if (i > 0) {
            out << ';';
        }
        out << values[i];
    }
    return out.str();
}

static std::string joinDoubles(const std::vector<double>& values) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(4);
    for (size_t i = 0; i < values.size(); ++i) {
        if (i > 0) {
            out << ';';
        }
        out << values[i];
    }
    return out.str();
}

static std::vector<std::string> splitString(const std::string& text, char delimiter) {
    std::vector<std::string> out;
    std::stringstream ss(text);
    std::string item;
    while (std::getline(ss, item, delimiter)) {
        out.push_back(item);
    }
    return out;
}

static bool ensureMemoryHeader(const std::string& filePath) {
    const std::string newHeader = "TimeSurvived,PhysicalDamageDone,MagicDamageDone,RawPhysicalDamageDone,RawMagicDamageDone,PlayerHealingReceived,PlayerHealth,PlayerSpeed,PlayerDefense,MeleeDamageScore,RangeDamageScore,ManaUsed,EnemySpawns,EnemyDamageByType,Reward";
    const std::string oldHeader = "TimeSurvived,PhysicalDamageDone,MagicDamageDone,PlayerHealingReceived,PlayerHealth,PlayerSpeed,PlayerDefense,MeleeDamageScore,RangeDamageScore,ManaUsed,EnemySpawns,EnemyDamageByType,Reward";

    std::ifstream in(filePath.c_str());
    if (!in.is_open()) {
        std::ofstream out(filePath.c_str(), std::ios::out | std::ios::trunc);
        if (!out.is_open()) {
            return false;
        }
        out << newHeader << "\n";
        return true;
    }

    std::vector<std::string> lines;
    std::string line;
    while (std::getline(in, line)) {
        lines.push_back(line);
    }
    in.close();

    if (lines.empty()) {
        std::ofstream out(filePath.c_str(), std::ios::out | std::ios::trunc);
        if (!out.is_open()) {
            return false;
        }
        out << newHeader << "\n";
        return true;
    }

    if (lines[0] == newHeader) {
        return true;
    }

    if (lines[0] != oldHeader) {
        return true;
    }

    std::ofstream out(filePath.c_str(), std::ios::out | std::ios::trunc);
    if (!out.is_open()) {
        return false;
    }
    out << newHeader << "\n";
    for (size_t i = 1; i < lines.size(); ++i) {
        if (lines[i].empty()) {
            continue;
        }
        // Old schema had only effective damage values. Duplicate into raw columns.
        std::vector<std::string> cols = splitString(lines[i], ',');
        if (cols.size() < 13) {
            continue;
        }
        out << cols[0] << "," << cols[1] << "," << cols[2] << "," << cols[1] << "," << cols[2] << ","
            << cols[3] << "," << cols[4] << "," << cols[5] << "," << cols[6] << "," << cols[7] << ","
            << cols[8] << "," << cols[9] << "," << cols[10] << "," << cols[11] << "," << cols[12] << "\n";
    }
    return true;
}

static bool appendDecisionToMemoryFile(const std::string& filePath, const DungeonAI::SpawningDecision& decision) {
    if (!ensureMemoryHeader(filePath)) {
        return false;
    }

    std::ofstream out(filePath.c_str(), std::ios::out | std::ios::app);
    if (!out.is_open()) {
        return false;
    }

    out << std::fixed << std::setprecision(4)
        << decision.timeSurvived << ","
        << decision.physicalDamageDone << ","
        << decision.magicDamageDone << ","
        << decision.rawPhysicalDamageDone << ","
        << decision.rawMagicDamageDone << ","
        << decision.playerHealingReceived << ","
        << decision.playerHealth << ","
        << decision.playerSpeed << ","
        << decision.playerDefense << ","
        << decision.meleeDamageScore << ","
        << decision.rangeDamageScore << ","
        << decision.manaUsed << ","
        << joinInts(decision.enemySpawns) << ","
        << joinDoubles(decision.enemyDamageByType) << ","
        << decision.reward << "\n";

    return true;
}

// Initialize enemy types with their stats and costs
void DungeonAI::initializeEnemyTypes() {
    // SKELETON_UNARMED
    Enemy unarmed;
    unarmed.type = SKELETON_UNARMED;
    unarmed.name = "Skeleton Unarmed";
    unarmed.manaCost = 1;
    unarmed.health = 10;
    unarmed.physicalDamage = 1;
    unarmed.magicDamage = 0;
    unarmed.physicalDefense = 1;
    unarmed.magicDefense = 1;
    unarmed.speed = 1.0;
    enemyTypes.push_back(unarmed);

    // SKELETON_SWORD
    Enemy sword;
    sword.type = SKELETON_SWORD;
    sword.name = "Skeleton Sword";
    sword.manaCost = 3;
    sword.health = 15;
    sword.physicalDamage = 5;
    sword.magicDamage = 0;
    sword.physicalDefense = 1;
    sword.magicDefense = 1;
    sword.speed = 0.75;
    enemyTypes.push_back(sword);

    // SKELETON_SHIELD
    Enemy shield;
    shield.type = SKELETON_SHIELD;
    shield.name = "Skeleton Shield";
    shield.manaCost = 3;
    shield.health = 25;
    shield.physicalDamage = 1;
    shield.magicDamage = 0;
    shield.physicalDefense = 4;
    shield.magicDefense = 4;
    shield.speed = 0.5;
    enemyTypes.push_back(shield);

    // SKELETON_SPEAR
    Enemy spear;
    spear.type = SKELETON_SPEAR;
    spear.name = "Skeleton Spear";
    spear.manaCost = 2;
    spear.health = 10;
    spear.physicalDamage = 3;
    spear.magicDamage = 0;
    spear.physicalDefense = 1;
    spear.magicDefense = 1;
    spear.speed = 0.8;
    enemyTypes.push_back(spear);

    // SKELETON_SWORD_SHIELD
    Enemy swordShield;
    swordShield.type = SKELETON_SWORD_SHIELD;
    swordShield.name = "Skeleton Sword & Shield";
    swordShield.manaCost = 5;
    swordShield.health = 25;
    swordShield.physicalDamage = 5;
    swordShield.magicDamage = 0;
    swordShield.physicalDefense = 2;
    swordShield.magicDefense = 2;
    swordShield.speed = 0.4;
    enemyTypes.push_back(swordShield);

    // SKELETON_MAGE
    Enemy skMage;
    skMage.type = SKELETON_MAGE;
    skMage.name = "Skeleton Mage";
    skMage.manaCost = 5;
    skMage.health = 10;
    skMage.physicalDamage = 0;
    skMage.magicDamage = 10;
    skMage.physicalDefense = 0;
    skMage.magicDefense = 5;
    skMage.speed = 2.0;
    enemyTypes.push_back(skMage);

    // SKELETON_BOW
    Enemy bow;
    bow.type = SKELETON_BOW;
    bow.name = "Skeleton Bow";
    bow.manaCost = 3;
    bow.health = 10;
    bow.physicalDamage = 5;
    bow.magicDamage = 0;
    bow.physicalDefense = 0;
    bow.magicDefense = 0;
    bow.speed = 1.5;
    enemyTypes.push_back(bow);

    // SKELETON_LEADER
    Enemy leader;
    leader.type = SKELETON_LEADER;
    leader.name = "Skeleton Leader";
    leader.manaCost = 15;
    leader.health = 50;
    leader.physicalDamage = 5;
    leader.magicDamage = 1;
    leader.physicalDefense = 4;
    leader.magicDefense = 4;
    leader.speed = 1.0;
    enemyTypes.push_back(leader);
}

// Normalize player stats to [0, 1] range for neural network input
Matrix DungeonAI::normalizePlayerStats(
    double physicalDamageTaken,
    double magicDamageTaken,
    double timeSurvived,
    double playerMeleeDamage,
    double playerRangeDamage,
    double playerHealth,
    double playerSpeed,
    double playerDefense,
    double playerHealingReceived,
    double dungeonMana)
{
    // Create input matrix: 1 x 10
    Matrix input(1, 10);

    // Normalize each stat to [0, 1] range
    // Using reasonable max values for normalization
    input.set(0, 0, std::min(physicalDamageTaken / 200.0, 1.0));     // 200 max physical damage
    input.set(0, 1, std::min(magicDamageTaken / 200.0, 1.0));        // 200 max magic damage
    input.set(0, 2, std::min(timeSurvived / 300.0, 1.0));            // 300 seconds max time
    input.set(0, 3, std::min(playerMeleeDamage / 30.0, 1.0));        // 30 max melee damage
    input.set(0, 4, std::min(playerRangeDamage / 30.0, 1.0));        // 30 max ranged damage
    input.set(0, 5, std::min(playerHealth / 200.0, 1.0));            // 200 max health
    input.set(0, 6, std::min(playerSpeed / 20.0, 1.0));              // 20 max speed
    input.set(0, 7, std::min(playerDefense / 50.0, 1.0));            // 50 max defense
    input.set(0, 8, std::min(playerHealingReceived / 200.0, 1.0));   // 200 max healing
    input.set(0, 9, std::min(dungeonMana / 500.0, 1.0));             // 500 max mana

    return input;
}

// Convert neural network output to spawn counts
std::vector<int> DungeonAI::outputToSpawns(const Matrix& networkOutput, double availableMana) {
    const int outputCount = std::min(static_cast<int>(enemyTypes.size()), networkOutput.getCols());
    std::vector<int> spawns(outputCount, 0);  // Count for each enemy type

    // Network output is 1xN, each value represents priority for spawning that enemy type
    // Values in [0, 1] from sigmoid activation
    
    double manaLeft = std::max(0.0, availableMana);
    double totalPriority = 0.0;

    // Calculate total priority
    for (int i = 0; i < outputCount; i++) {
        totalPriority += networkOutput.get(0, i);
    }

    if (totalPriority <= 0.0 || manaLeft <= 0.0) {
        return spawns;
    }

    // Initial proportional allocation based on the full available mana.
    for (int i = 0; i < outputCount; i++) {
        const int manaCost = std::max(1, enemyTypes[i].manaCost);
        const double priority = std::max(0.0, networkOutput.get(0, i)) / totalPriority;
        const double allocatedMana = availableMana * priority;
        const int count = static_cast<int>(allocatedMana / manaCost);
        spawns[i] = std::max(0, count);
        manaLeft -= static_cast<double>(spawns[i] * manaCost);
    }

    // Spend leftover mana with weighted random sampling across affordable enemies.
    // Sampling only from strictly positive network priorities allows the model
    // to suppress obsolete enemy types through learning.
    static std::mt19937 rng(std::random_device{}());
    while (manaLeft >= 1.0) {
        std::vector<int> affordableIndices;
        std::vector<double> affordableWeights;
        double totalWeight = 0.0;

        for (int i = 0; i < outputCount; i++) {
            const int manaCost = std::max(1, enemyTypes[i].manaCost);
            if (manaCost > manaLeft) {
                continue;
            }

            const double weight = std::max(0.0, networkOutput.get(0, i));
            if (weight <= 0.0) {
                continue;
            }
            affordableIndices.push_back(i);
            affordableWeights.push_back(weight);
            totalWeight += weight;
        }

        if (affordableIndices.empty() || totalWeight <= 0.0) {
            break;
        }

        std::discrete_distribution<int> pick(affordableWeights.begin(), affordableWeights.end());
        const int chosenLocalIndex = pick(rng);
        const int chosenEnemyIndex = affordableIndices[chosenLocalIndex];
        const int chosenCost = std::max(1, enemyTypes[chosenEnemyIndex].manaCost);

        spawns[chosenEnemyIndex] += 1;
        manaLeft -= static_cast<double>(chosenCost);
    }

    return spawns;
}

// Main decision function: What enemies to spawn given player stats
std::vector<int> DungeonAI::decideEnemySpawns(
    double physicalDamageTaken,
    double magicDamageTaken,
    double timeSurvived,
    double playerMeleeDamage,
    double playerRangeDamage,
    double playerHealth,
    double playerSpeed,
    double playerDefense,
    double playerHealingReceived,
    double dungeonMana)
{
    // Step 1: Normalize player stats
    Matrix input = normalizePlayerStats(
        physicalDamageTaken,
        magicDamageTaken,
        timeSurvived,
        playerMeleeDamage,
        playerRangeDamage,
        playerHealth,
        playerSpeed,
        playerDefense,
        playerHealingReceived,
        dungeonMana
    );

    // Step 2: Get neural network prediction
    // Network learns: given player stats, what enemy composition maximizes:
    // - Time player survives (longer game = better)
    // - Damage dealt to player (higher damage = higher challenge)
    Matrix networkOutput = aiNetwork.predict(input);

    // Step 3: Convert network output to spawn counts
    std::vector<int> spawns = outputToSpawns(networkOutput, dungeonMana);

    return spawns;
}

// Calculate reward for a spawning decision
// Reward is proportional to damage done and time survived, scaled by mana efficiency
double DungeonAI::calculateReward(double timeSurvived, double totalDamageDone, int manaUsed) {
    // Goals:
    // 1. Maximize time (longer = more engagement)
    // 2. Maximize damage (higher challenge)
    // 3. Use mana efficiently
    
    // Normalize components
    double timeScore = timeSurvived / 300.0;           // Normalized to 0-1
    double damageScore = totalDamageDone / 300.0;      // Normalized to 0-1
    double efficiencyScore = 1.0 - (manaUsed / 500.0); // Mana efficiency

    // Combined reward (weighted average)
    // 40% time, 50% damage, 10% efficiency
    double reward = (0.4 * timeScore) + (0.5 * damageScore) + (0.1 * efficiencyScore);

    // Clamp to [0, 1]
    return std::min(std::max(reward, 0.0), 1.0);
}

// Record a game outcome for training
void DungeonAI::recordDecision(
    double timeSurvived,
    double physicalDamageDone,
    double magicDamageDone,
    double rawPhysicalDamageDone,
    double rawMagicDamageDone,
    double playerHealingReceived,
    double playerHealth,
    double playerSpeed,
    double playerDefense,
    int meleeDamageScore,
    int rangeDamageScore,
    int manaUsed,
    const std::vector<int>& spawns,
    const std::vector<double>& enemyDamageByType,
    double reward)
{
    SpawningDecision decision;
    decision.timeSurvived = timeSurvived;
    decision.physicalDamageDone = physicalDamageDone;
    decision.magicDamageDone = magicDamageDone;
    decision.rawPhysicalDamageDone = rawPhysicalDamageDone;
    decision.rawMagicDamageDone = rawMagicDamageDone;
    decision.playerHealingReceived = playerHealingReceived;
    decision.playerHealth = playerHealth;
    decision.playerSpeed = playerSpeed;
    decision.playerDefense = playerDefense;
    decision.meleeDamageScore = meleeDamageScore;
    decision.rangeDamageScore = rangeDamageScore;
    decision.manaUsed = manaUsed;
    decision.enemySpawns = spawns;
    decision.enemyDamageByType = enemyDamageByType;
    decision.reward = reward;

    decisionHistory.push_back(decision);
    appendDecisionToMemoryFile(memoryFilePath, decision);
}

int DungeonAI::loadMemoryFromFileAndTrain(int epochs) {
    std::ifstream in(memoryFilePath.c_str());
    if (!in.is_open()) {
        return 0;
    }

    std::string line;
    std::vector<SpawningDecision> loaded;

    // Skip header.
    std::getline(in, line);

    while (std::getline(in, line)) {
        if (line.empty()) {
            continue;
        }

        std::vector<std::string> cols = splitString(line, ',');
        if (cols.size() < 13) {
            continue;
        }

        try {
            SpawningDecision d = {};
            d.timeSurvived = std::stod(cols[0]);
            d.physicalDamageDone = std::stod(cols[1]);
            d.magicDamageDone = std::stod(cols[2]);
            int colOffset = 0;
            if (cols.size() >= 15) {
                d.rawPhysicalDamageDone = std::stod(cols[3]);
                d.rawMagicDamageDone = std::stod(cols[4]);
                colOffset = 2;
            } else {
                d.rawPhysicalDamageDone = d.physicalDamageDone;
                d.rawMagicDamageDone = d.magicDamageDone;
            }

            d.playerHealingReceived = std::stod(cols[3 + colOffset]);
            d.playerHealth = std::stod(cols[4 + colOffset]);
            d.playerSpeed = std::stod(cols[5 + colOffset]);
            d.playerDefense = std::stod(cols[6 + colOffset]);
            d.meleeDamageScore = std::stoi(cols[7 + colOffset]);
            d.rangeDamageScore = std::stoi(cols[8 + colOffset]);
            d.manaUsed = std::stoi(cols[9 + colOffset]);

            std::vector<std::string> spawnParts = splitString(cols[10 + colOffset], ';');
            for (size_t i = 0; i < spawnParts.size(); ++i) {
                if (!spawnParts[i].empty()) {
                    d.enemySpawns.push_back(std::stoi(spawnParts[i]));
                }
            }

            std::vector<std::string> dmgParts = splitString(cols[11 + colOffset], ';');
            for (size_t i = 0; i < dmgParts.size(); ++i) {
                if (!dmgParts[i].empty()) {
                    d.enemyDamageByType.push_back(std::stod(dmgParts[i]));
                }
            }

            d.reward = std::stod(cols[12 + colOffset]);
            loaded.push_back(d);
        } catch (...) {
            // Ignore malformed rows.
        }
    }

    if (!loaded.empty()) {
        trainOnGameHistories(loaded, std::max(1, epochs));
        decisionHistory = loaded;
    }

    return static_cast<int>(loaded.size());
}

bool DungeonAI::resetPersistentTrainingData() {
    resetAllMemory();

    std::ofstream out(memoryFilePath.c_str(), std::ios::out | std::ios::trunc);
    if (!out.is_open()) {
        return false;
    }
    out << "TimeSurvived,PhysicalDamageDone,MagicDamageDone,RawPhysicalDamageDone,RawMagicDamageDone,PlayerHealingReceived,PlayerHealth,PlayerSpeed,PlayerDefense,MeleeDamageScore,RangeDamageScore,ManaUsed,EnemySpawns,EnemyDamageByType,Reward\n";
    return true;
}

double DungeonAI::normalizeScore(double score) const {
    // Supports either [0,1] scores or [0,100] scores.
    if (score > 1.0) {
        score /= 100.0;
    }
    return std::min(std::max(score, 0.0), 1.0);
}

Matrix DungeonAI::buildTargetFromOutcome(
    const std::vector<int>& spawns,
    const std::vector<double>& enemyDamageByType,
    double score
) const {
    Matrix target(1, networkShape.back());
    double normalizedScore = normalizeScore(score);
    const int outputCount = target.getCols();

    const int count = std::min({
        outputCount,
        static_cast<int>(enemyDamageByType.size()),
        static_cast<int>(spawns.size()),
        static_cast<int>(enemyTypes.size())
    });

    std::vector<double> damageByType(outputCount, 0.0);
    std::vector<double> efficiencyByType(outputCount, 0.0);
    std::vector<double> wasteByType(outputCount, 0.0);

    double totalDamage = 0.0;
    double maxEfficiency = 0.0;
    double totalWastedMana = 0.0;

    for (int i = 0; i < count; i++) {
        const double damage = std::max(0.0, enemyDamageByType[i]);
        const int spawned = std::max(0, spawns[i]);
        const int manaCost = std::max(1, enemyTypes[i].manaCost);
        const double manaSpent = static_cast<double>(spawned * manaCost);

        damageByType[i] = damage;
        totalDamage += damage;

        if (manaSpent > 0.0) {
            const double efficiency = damage / manaSpent;
            efficiencyByType[i] = efficiency;
            if (efficiency > maxEfficiency) {
                maxEfficiency = efficiency;
            }

            if (damage <= 0.0 && spawned > 0) {
                wasteByType[i] = manaSpent;
                totalWastedMana += manaSpent;
            }
        }
    }

    double utilitySum = 0.0;
    for (int i = 0; i < count; i++) {
        const double damageComponent = (totalDamage > 0.0) ? (damageByType[i] / totalDamage) : 0.0;
        const double efficiencyComponent = (maxEfficiency > 0.0) ? (efficiencyByType[i] / maxEfficiency) : 0.0;
        const double wasteComponent = (totalWastedMana > 0.0) ? (wasteByType[i] / totalWastedMana) : 0.0;

        // Channel quality-of-spawn learning: reward damage and damage-per-mana,
        // penalize enemies that consumed mana but contributed no damage.
        double utility = (0.65 * damageComponent) + (0.35 * efficiencyComponent) - (0.60 * wasteComponent);
        utility = std::max(0.0, utility);
        target.set(0, i, utility);
        utilitySum += utility;
    }

    if (utilitySum > 0.0) {
        for (int i = 0; i < count; i++) {
            target.set(0, i, (target.get(0, i) / utilitySum) * normalizedScore);
        }
        return target;
    }

    int totalSpawned = 0;
    for (int count : spawns) {
        totalSpawned += std::max(0, count);
    }

    if (totalSpawned == 0) {
        return target;
    }

    const int spawnCount = std::min(static_cast<int>(spawns.size()), outputCount);
    for (int i = 0; i < spawnCount; i++) {
        double proportion = static_cast<double>(std::max(0, spawns[i])) / totalSpawned;
        target.set(0, i, proportion * normalizedScore);
    }

    return target;
}

void DungeonAI::resetAllMemory() {
    // Forget all interaction history and reinitialize network weights.
    decisionHistory.clear();
    aiNetwork = NeuralNetwork(networkShape, defaultLearningRate);
}

void DungeonAI::learnFromInteraction(
    double physicalDamageTaken,
    double magicDamageTaken,
    double timeSurvived,
    double playerMeleeDamage,
    double playerRangeDamage,
    double playerHealth,
    double playerSpeed,
    double playerDefense,
    double playerHealingReceived,
    double dungeonMana,
    const std::vector<int>& spawns,
    const std::vector<double>& enemyDamageByType,
    double score,
    bool playerDied,
    double rawPhysicalDamageTaken,
    double rawMagicDamageTaken)
{
    const double rawPhysical = (rawPhysicalDamageTaken >= 0.0) ? rawPhysicalDamageTaken : physicalDamageTaken;
    const double rawMagic = (rawMagicDamageTaken >= 0.0) ? rawMagicDamageTaken : magicDamageTaken;

    // If player died, score the run then wipe memory to nothing.
    if (playerDied) {
        std::cout << "Player died. Final score: " << score << "\n";
        if (!keepMemoryOnDeath) {
            std::cout << "Resetting AI memory to empty state...\n";
            resetAllMemory();
            return;
        }
        std::cout << "Hard mode enabled: keeping AI memory after death.\n";
    }

    // Learn immediately from this single interaction.
    Matrix input = normalizePlayerStats(
        physicalDamageTaken,
        magicDamageTaken,
        timeSurvived,
        playerMeleeDamage,
        playerRangeDamage,
        playerHealth,
        playerSpeed,
        playerDefense,
        playerHealingReceived,
        dungeonMana
    );

    Matrix target = buildTargetFromOutcome(spawns, enemyDamageByType, score);

    // Feed prediction vs. learned target into the decision matrix for analysis,
    // giving visibility into whether the network is shifting away from obsolete spawns.
    Matrix prediction = aiNetwork.predict(input);
    aiNetwork.updateDecisionMatrix(prediction, target, 0);

    // Online learning step (single sample update).
    aiNetwork.backpropagate(input, target);

    int manaUsed = 0;
    const int manaCount = std::min(static_cast<int>(spawns.size()), static_cast<int>(enemyTypes.size()));
    for (int i = 0; i < manaCount; i++) {
        manaUsed += std::max(0, spawns[i]) * enemyTypes[i].manaCost;
    }

    // Track interaction in episode memory for analysis.
    recordDecision(
        timeSurvived,
        physicalDamageTaken,
        magicDamageTaken,
        rawPhysical,
        rawMagic,
        playerHealingReceived,
        playerHealth,
        playerSpeed,
        playerDefense,
        static_cast<int>(playerMeleeDamage),
        static_cast<int>(playerRangeDamage),
        manaUsed,
        spawns,
        enemyDamageByType,
        normalizeScore(score)
    );
}

// Train AI on accumulated game history
void DungeonAI::trainOnGameHistories(const std::vector<SpawningDecision>& histories, int epochs) {
    std::cout << "\n=== Training Dungeon AI on " << histories.size() << " game sessions ===\n";

    // Prepare training data from game history
    std::vector<Matrix> inputs;
    std::vector<Matrix> targets;

    for (const auto& history : histories) {
        // Create input from game stats (normalized)
        Matrix input = normalizePlayerStats(
            history.physicalDamageDone,
            history.magicDamageDone,
            history.timeSurvived,
            history.meleeDamageScore,
            history.rangeDamageScore,
            history.playerHealth,
            history.playerSpeed,
            history.playerDefense,
            history.playerHealingReceived,
            history.manaUsed
        );

        Matrix target = buildTargetFromOutcome(
            history.enemySpawns,
            history.enemyDamageByType,
            history.reward
        );

        inputs.push_back(input);
        targets.push_back(target);
    }

    // Train network on this data
    if (!inputs.empty()) {
        aiNetwork.train(inputs, targets, epochs);
    }

    std::cout << "Training complete!\n";
}

// Print analysis of AI's spawning patterns
void DungeonAI::printAIAnalysis() {
    std::cout << "\n=== Dungeon AI Analysis ===\n";
    std::cout << "Decision History: " << decisionHistory.size() << " recorded decisions\n\n";

    if (decisionHistory.empty()) {
        std::cout << "No decisions recorded yet.\n";
        return;
    }

    // Calculate statistics
    double totalReward = 0.0;
    double avgTimeSurvived = 0.0;
    double avgDamageDone = 0.0;
    int totalManaUsed = 0;
    std::vector<int> enemySpawnTotals(enemyTypes.size(), 0);

    for (const auto& decision : decisionHistory) {
        totalReward += decision.reward;
        avgTimeSurvived += decision.timeSurvived;
        avgDamageDone += decision.physicalDamageDone + decision.magicDamageDone;
        totalManaUsed += decision.manaUsed;

        const int count = std::min(static_cast<int>(decision.enemySpawns.size()), static_cast<int>(enemySpawnTotals.size()));
        for (int i = 0; i < count; i++) {
            enemySpawnTotals[i] += decision.enemySpawns[i];
        }
    }

    int numDecisions = decisionHistory.size();
    avgTimeSurvived /= numDecisions;
    avgDamageDone /= numDecisions;

    std::cout << "Average Reward: " << (totalReward / numDecisions) << "\n";
    std::cout << "Average Time Survived: " << avgTimeSurvived << " seconds\n";
    std::cout << "Average Damage Done: " << avgDamageDone << "\n";
    std::cout << "Total Mana Used: " << totalManaUsed << "\n";
    std::cout << "\nEnemy Spawn Totals:\n";
    for (size_t i = 0; i < enemyTypes.size(); i++) {
        std::cout << "  " << enemyTypes[i].name << ": " << enemySpawnTotals[i] << "\n";
    }
}

// Print detailed info about a spawning strategy
void DungeonAI::printSpawningStrategy(const std::vector<int>& spawns) {
    std::cout << "\n=== Spawning Strategy ===\n";
    
    int totalMana = 0;
    const int count = std::min(static_cast<int>(spawns.size()), static_cast<int>(enemyTypes.size()));
    for (int i = 0; i < count; i++) {
        if (spawns[i] > 0) {
            int manaUsed = spawns[i] * enemyTypes[i].manaCost;
            totalMana += manaUsed;
            
            std::cout << "Spawn " << spawns[i] << " " << enemyTypes[i].name 
                      << " (Mana: " << manaUsed << ")\n";
            
            // Calculate total expected damage
            double totalPhysical = spawns[i] * enemyTypes[i].physicalDamage;
            double totalMagic = spawns[i] * enemyTypes[i].magicDamage;
            
            std::cout << "  - Total Physical Damage: " << totalPhysical << "\n";
            std::cout << "  - Total Magic Damage: " << totalMagic << "\n";
        }
    }
    
    std::cout << "Total Mana Cost: " << totalMana << "\n";
    
    // Calculate total damage potential
    double totalPhysical = 0.0, totalMagic = 0.0;
    for (int i = 0; i < count; i++) {
        totalPhysical += spawns[i] * enemyTypes[i].physicalDamage;
        totalMagic += spawns[i] * enemyTypes[i].magicDamage;
    }
    
    std::cout << "\nTotal Expected Damage: " << (totalPhysical + totalMagic) << "\n";
    std::cout << "  Physical: " << totalPhysical << "\n";
    std::cout << "  Magic: " << totalMagic << "\n";
}
