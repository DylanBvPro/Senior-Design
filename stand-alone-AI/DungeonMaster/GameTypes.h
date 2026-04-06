#pragma once

struct UserInteractionInput {
    double timeSurvived;
    double physicalDamage;
    double magicDamage;
    double meleeDamage;
    double rangeDamage;
    double health;
    double speed;
    double defense;
    double healingReceived;
    double dungeonMana;
    bool playerDied;
    bool endManualRunRequested;
};

struct RunScores {
    int runNumber;
    double aiScorePercent;
    double playerScorePercent;
    bool playerDied;
};