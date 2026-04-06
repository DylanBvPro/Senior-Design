#ifndef DUNGEON_AI_H
#define DUNGEON_AI_H

#include "NeuralNetwork.h"
#include <vector>
#include <string>

// ============================================================================
// ENEMY TYPE DEFINITIONS
// ============================================================================
// Different enemy types with varying characteristics and costs

enum EnemyType {
    SKELETON_UNARMED = 0,
    SKELETON_SWORD = 1,
    SKELETON_SHIELD = 2,
    SKELETON_SPEAR = 3,
    SKELETON_SWORD_SHIELD = 4,
    SKELETON_MAGE = 5,
    SKELETON_BOW = 6,
    SKELETON_LEADER = 7,
    SKELETON_TYPE_COUNT = 8
};

struct Enemy {
    EnemyType type;
    double health;
    double physicalDamage;
    double magicDamage;
    double physicalDefense;
    double magicDefense;
    double speed;
    int manaCost;            // Cost to spawn this enemy
    std::string name;
};

// ============================================================================
// DUNGEON AI ENGINE
// ============================================================================
// Uses neural network to decide what enemies to spawn based on player stats
class DungeonAI {
private:
    const std::vector<int> networkShape;
    const double defaultLearningRate;
    NeuralNetwork aiNetwork;
    std::vector<Enemy> enemyTypes;
    double dungeonManaAvailable;
    bool keepMemoryOnDeath;
    std::string memoryFilePath;
    
public:
    // Stores decision history for analysis and episode memory
    struct SpawningDecision {
        double timeSurvived;
        double physicalDamageDone;
        double magicDamageDone;
        double rawPhysicalDamageDone;
        double rawMagicDamageDone;
        double playerHealingReceived;
        double playerHealth;
        double playerSpeed;
        double playerDefense;
        int meleeDamageScore;
        int rangeDamageScore;
        int manaUsed;
        std::vector<int> enemySpawns;  // Count of each enemy type spawned
        std::vector<double> enemyDamageByType; // Actual damage dealt per enemy type
        double reward;                 // Calculated reward for this decision
    };

private:
    std::vector<SpawningDecision> decisionHistory;

public:
    // Constructor: Initialize AI with neural network
    // Network input: 10 features (player stats + healing received)
    // Network output: How many of each enemy type to spawn + rewards
    DungeonAI(double availableMana);

    // Main function: Decide what enemies to spawn
    // Inputs:
    //   - physicalDamageTaken: damage player has suffered (physical)
    //   - magicDamageTaken: damage player has suffered (magic)
    //   - timeSurvived: how long player has survived
    //   - playerMeleeDamage: damage player deals with melee weapon
    //   - playerRangeDamage: damage player deals with ranged weapon
    //   - playerHealth: current player health
    //   - playerSpeed: current player speed
    //   - playerDefense: current player defense
    //   - playerHealingReceived: healing player received from enemy interactions
    //   - dungeonMana: available mana for spawning
    // Returns: vector of enemy spawning counts
    std::vector<int> decideEnemySpawns(
        double physicalDamageTaken,
        double magicDamageTaken,
        double timeSurvived,
        double playerMeleeDamage,
        double playerRangeDamage,
        double playerHealth,
        double playerSpeed,
        double playerDefense,
        double playerHealingReceived,
        double dungeonMana
    );

    // Train the AI on past game sessions
    // histories: vector of previous game outcomes
    void trainOnGameHistories(const std::vector<SpawningDecision>& histories, int epochs);

    // Record a spawning decision and its outcome for future training
    void recordDecision(
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
        double reward
    );

    // Learn from one interaction in real-time.
    // score: player-facing score for this interaction/encounter.
    // playerDied: if true, AI prints final score and resets all memory.
    void learnFromInteraction(
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
        double rawPhysicalDamageTaken = -1.0,
        double rawMagicDamageTaken = -1.0
    );

    // Reset all AI memory: clears interaction history and neural network weights.
    void resetAllMemory();

    // Configure whether AI keeps learned memory when player dies.
    void setKeepMemoryOnDeath(bool keep) { keepMemoryOnDeath = keep; }
    bool getKeepMemoryOnDeath() const { return keepMemoryOnDeath; }

    // Persistent memory file controls (used by hard mode bootstrap).
    void setMemoryFilePath(const std::string& path) { memoryFilePath = path; }
    const std::string& getMemoryFilePath() const { return memoryFilePath; }
    int loadMemoryFromFileAndTrain(int epochs = 3);
    bool resetPersistentTrainingData();

    // Returns how many interactions are currently stored in episode memory.
    int getEpisodeMemorySize() const { return static_cast<int>(decisionHistory.size()); }

    // Calculate reward for a spawning decision
    // Goal: maximize time survived + maximize damage done
    // Scaled by how efficiently mana was used
    double calculateReward(double timeSurvived, double totalDamageDone, int manaUsed);

    // Analyze current AI performance
    void printAIAnalysis();

    // Get detailed information about a spawning decision
    void printSpawningStrategy(const std::vector<int>& spawns);

    // Get available enemy types
    const std::vector<Enemy>& getEnemyTypes() const { return enemyTypes; }

private:
    // Initialize enemy types with their stats
    void initializeEnemyTypes();

    // Convert player stats to normalized input vector for neural network
    Matrix normalizePlayerStats(
        double physicalDamageTaken,
        double magicDamageTaken,
        double timeSurvived,
        double playerMeleeDamage,
        double playerRangeDamage,
        double playerHealth,
        double playerSpeed,
        double playerDefense,
        double playerHealingReceived,
        double dungeonMana
    );

    // Convert neural network output to enemy spawn counts
    std::vector<int> outputToSpawns(const Matrix& networkOutput, double availableMana);

    // Calculate how many enemies can be spawned given mana constraint
    int calculateSpawnCount(EnemyType type, double manaAvailable);

    // Select counter-enemies based on player weapon damage
    // If player is strong at melee, spawn enemies weak to melee
    // If player is strong at ranged, spawn enemies weak to ranged
    EnemyType selectCounterEnemy(double meleeDamage, double rangeDamage);

    // Build a target vector for online learning using real per-enemy damage attribution.
    Matrix buildTargetFromOutcome(
        const std::vector<int>& spawns,
        const std::vector<double>& enemyDamageByType,
        double score
    ) const;

    // Utility: clamp score to [0, 1] range.
    double normalizeScore(double score) const;
};

#endif // DUNGEON_AI_H
