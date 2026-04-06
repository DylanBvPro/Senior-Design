#include "GraphUtils.h"
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <iostream>
#include <cmath>
#include <fstream>

#ifdef _WIN32
#include <windows.h>
#endif

static std::string toSparkline(const std::vector<double>& values) {
    static const char* levels[] = {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"};

    if (values.empty()) {
        return "(no data)";
    }

    const auto minmax = std::minmax_element(values.begin(), values.end());
    const double minValue = *minmax.first;
    const double maxValue = *minmax.second;
    const double span = std::max(1e-9, maxValue - minValue);

    std::ostringstream line;
    for (double value : values) {
        double normalized = (value - minValue) / span;
        int index = static_cast<int>(std::round(normalized * 7.0));
        index = std::max(0, std::min(7, index));
        line << levels[index];
    }
    return line.str();
}

static void appendSeries(
    std::ostringstream& out,
    const std::string& label,
    const std::vector<double>& values
) {
    out << std::left << std::setw(18) << label << " " << toSparkline(values);
    if (!values.empty()) {
        const auto minmax = std::minmax_element(values.begin(), values.end());
        out << "  (min=" << std::fixed << std::setprecision(2) << *minmax.first
            << ", max=" << *minmax.second << ")";
    }
    out << "\n";
}

static std::string buildAutoRunTextFallback(
    const std::vector<double>& manaHistory,
    const std::vector<double>& healthHistory,
    const std::vector<double>& healingHistory,
    const std::vector<double>& damageToPlayerHistory,
    const std::vector<double>& enemyCountHistory
) {
    (void)manaHistory;
    (void)healingHistory;
    (void)enemyCountHistory;

    std::ostringstream out;
    out << "SIMPLE XY GRAPH\n";
    out << "X = Run Number\n";
    out << "Y = Aggro, Player Health\n";
    out << "Aggro is derived from damage-to-player each run.\n\n";

    if (healthHistory.empty() || damageToPlayerHistory.empty()) {
        out << "No graph data available.";
        return out.str();
    }

    const size_t pointCount = std::min(healthHistory.size(), damageToPlayerHistory.size());
    if (pointCount == 0) {
        out << "No graph data available.";
        return out.str();
    }

    std::vector<double> aggroHistory(pointCount, 0.0);
    std::vector<double> clippedHealth(pointCount, 0.0);
    for (size_t i = 0; i < pointCount; ++i) {
        aggroHistory[i] = damageToPlayerHistory[i];
        clippedHealth[i] = healthHistory[i];
    }

    out << std::left << std::setw(8) << "Run"
        << std::setw(14) << "Aggro"
        << std::setw(14) << "Health" << "\n";
    out << "--------------------------------------\n";

    for (size_t i = 0; i < pointCount; ++i) {
        out << std::left << std::setw(8) << static_cast<int>(i + 1)
            << std::setw(14) << std::fixed << std::setprecision(2) << aggroHistory[i]
            << std::setw(14) << clippedHealth[i] << "\n";
    }

    out << "\n";
    appendSeries(out, "Aggro", aggroHistory);
    appendSeries(out, "Player Health", clippedHealth);

    out << "\nOpen auto_run_metrics.csv in Excel to plot this as an XY line chart.";

    return out.str();
}

static std::string buildEnemyTypeTextFallback(
    const std::vector<std::string>& enemyTypeNames,
    const std::vector<std::vector<double>>& enemyTypeCountsOverTime
) {
    (void)enemyTypeNames;
    (void)enemyTypeCountsOverTime;

    std::ostringstream out;
    out << "Enemy type graph removed.\n";
    out << "Use auto_run_metrics.csv -> EnemyTypeCounts to inspect per-round enemy counts.";
    return out.str();
}

std::string buildAutoRunLineGraphText(
    const std::vector<double>& manaHistory,
    const std::vector<double>& healthHistory,
    const std::vector<double>& healingHistory,
    const std::vector<double>& damageToPlayerHistory,
    const std::vector<double>& enemyCountHistory
) {
    return buildAutoRunTextFallback(
        manaHistory,
        healthHistory,
        healingHistory,
        damageToPlayerHistory,
        enemyCountHistory
    );
}

std::string buildEnemyTypeLineChartText(
    const std::vector<std::string>& enemyTypeNames,
    const std::vector<std::vector<double>>& enemyTypeCountsOverTime
) {
    return buildEnemyTypeTextFallback(
        enemyTypeNames,
        enemyTypeCountsOverTime
    );
}

void showAutoRunGraphWindow(const std::string& graphText) {
    if (graphText.empty()) {
        return;
    }
#ifdef _WIN32
    MessageBoxA(nullptr, graphText.c_str(), "Auto Run Graph", MB_OK | MB_ICONINFORMATION);
#else
    std::cout << "\n" << graphText << "\n";
#endif
}

int getNextAutoRunGameNumber(const std::string& csvPath) {
    std::ifstream in(csvPath.c_str());
    if (!in.is_open()) {
        return 1;
    }

    std::string line;
    int maxGameNumber = 0;
    while (std::getline(in, line)) {
        if (line.empty()) {
            continue;
        }

        const size_t comma = line.find(',');
        const std::string firstColumn = (comma == std::string::npos) ? line : line.substr(0, comma);

        try {
            const int value = std::stoi(firstColumn);
            if (value > maxGameNumber) {
                maxGameNumber = value;
            }
        } catch (...) {
            // Skip header and malformed rows.
        }
    }

    return maxGameNumber + 1;
}

static std::string csvEscape(const std::string& value) {
    std::string escaped;
    escaped.reserve(value.size() + 2);
    escaped.push_back('"');
    for (size_t i = 0; i < value.size(); ++i) {
        if (value[i] == '"') {
            escaped.push_back('"');
        }
        escaped.push_back(value[i]);
    }
    escaped.push_back('"');
    return escaped;
}

static const char* kV1Header = "GameNumber,RunNumber,ManaUsed,PlayerHealth,PlayerHealing,DamageToPlayer,EnemyCount";
static const char* kV2Header = "GameNumber,RunNumber,ManaUsed,PlayerHealth,PlayerHealing,DamageToPlayer,EnemyCount,EnemyTypeCounts";
static const char* kV3Header = "GameNumber,RunNumber,ManaUsed,PlayerHealth,PlayerHealing,DamageToPlayer,EnemyCount,EnemyTypeCounts,PlayerSpeed,PlayerDefense";
static const char* kV4Header = "GameNumber,RunNumber,ManaUsed,PlayerHealth,PlayerHealing,DamageToPlayer,EnemyCount,EnemyTypeCounts,PlayerSpeed,PlayerDefense,AIScorePercent";

static bool migrateAutoRunCsvHeaderIfNeeded(const std::string& csvPath) {
    std::ifstream in(csvPath.c_str());
    if (!in.is_open()) {
        return true;
    }

    std::vector<std::string> lines;
    std::string line;
    while (std::getline(in, line)) {
        lines.push_back(line);
    }
    in.close();

    if (lines.empty()) {
        return true;
    }

    if (lines[0] == kV4Header) {
        return true;
    }

    if (lines[0] != kV1Header && lines[0] != kV2Header && lines[0] != kV3Header) {
        return true;
    }

    std::ofstream out(csvPath.c_str(), std::ios::out | std::ios::trunc);
    if (!out.is_open()) {
        return false;
    }

    out << kV4Header << "\n";
    for (size_t i = 1; i < lines.size(); ++i) {
        if (lines[i].empty()) {
            continue;
        }
        if (lines[0] == kV1Header) {
            out << lines[i] << ",0.00,\"\",0.00,0.00\n";
            continue;
        }
        if (lines[0] == kV2Header) {
            out << lines[i] << ",0.00,0.00,0.00\n";
            continue;
        }
        out << lines[i] << ",0.00\n";
    }

    return true;
}

static bool ensureAutoRunCsvHeader(const std::string& csvPath) {
    if (!migrateAutoRunCsvHeaderIfNeeded(csvPath)) {
        return false;
    }

    bool needsHeader = true;
    {
        std::ifstream in(csvPath.c_str(), std::ios::binary);
        if (in.is_open()) {
            char first = '\0';
            if (in.get(first)) {
                needsHeader = false;
            }
        }
    }

    if (!needsHeader) {
        return true;
    }

    std::ofstream out(csvPath.c_str(), std::ios::out | std::ios::trunc);
    if (!out.is_open()) {
        return false;
    }

    out << kV4Header << "\n";
    return true;
}

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
) {
    if (!ensureAutoRunCsvHeader(csvPath)) {
        return false;
    }

    std::ofstream out(csvPath.c_str(), std::ios::out | std::ios::app);
    if (!out.is_open()) {
        return false;
    }

    out << gameNumber << ","
        << runNumber << ","
        << std::fixed << std::setprecision(2)
        << manaUsed << ","
        << playerHealth << ","
        << playerHealing << ","
        << damageToPlayer << ","
        << enemyCount << ","
        << csvEscape(enemyTypeCounts) << ","
        << playerSpeed << ","
        << playerDefense << ","
        << aiScorePercent << "\n";

    return true;
}