#pragma once
#include <vector>
#include <string>

std::string buildAutoRunLineGraphText(
    const std::vector<double>& manaHistory,
    const std::vector<double>& healthHistory,
    const std::vector<double>& healingHistory,
    const std::vector<double>& damageToPlayerHistory,
    const std::vector<double>& enemyCountHistory
);

std::string buildEnemyTypeLineChartText(
    const std::vector<std::string>& enemyTypeNames,
    const std::vector<std::vector<double>>& enemyTypeCountsOverTime
);

void showAutoRunGraphWindow(const std::string& graphText);

int getNextAutoRunGameNumber(const std::string& csvPath);

bool appendAutoRunMetricRowToExcelCsv(
    const std::string& csvPath,
    int gameNumber,
    int runNumber,
    double manaUsed,
    double playerHealth,
    double playerHealing,
    double damageToPlayer,
    double aiScorePercent,
    double enemyCount,
    const std::string& enemyTypeCounts,
    double playerSpeed,
    double playerDefense
);