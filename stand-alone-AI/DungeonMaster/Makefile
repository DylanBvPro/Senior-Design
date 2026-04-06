# Makefile for Neural Network and Dungeon AI Project
# Compiles all C++ files and creates executables

# Compiler and flags
CXX = g++
CXXFLAGS = -std=c++11 -Wall -Wextra -O2
LDFLAGS =
LDLIBS =

# Target executables
TARGET_NN = neural_network
TARGET_DUNGEON = dungeon_master

# Source files
SOURCES_NN = main.cpp NeuralNetwork.cpp
SOURCES_DUNGEON = dungeon_main.cpp DungeonAI.cpp NeuralNetwork.cpp GraphUtils.cpp PopupUI.cpp
HEADERS = Matrix.h NeuralNetwork.h DungeonAI.h GraphUtils.h PopupUI.h GameTypes.h

# Object files
OBJECTS_NN = main.o NeuralNetwork.o
OBJECTS_DUNGEON = dungeon_main.o DungeonAI.o NeuralNetwork.o GraphUtils.o PopupUI.o

# Default target: build both
all: $(TARGET_NN) $(TARGET_DUNGEON)
	@echo "✓ Build complete!"
	@echo "  Run neural network:  ./$(TARGET_NN)"
	@echo "  Run dungeon AI:      ./$(TARGET_DUNGEON)"

# Build neural network demo
$(TARGET_NN): $(OBJECTS_NN)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $(TARGET_NN) $(OBJECTS_NN) $(LDLIBS)
	@echo "✓ Neural network build complete! Run with: ./$(TARGET_NN)"

# Build dungeon AI
$(TARGET_DUNGEON): $(OBJECTS_DUNGEON)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $(TARGET_DUNGEON) $(OBJECTS_DUNGEON) $(LDLIBS)
	@echo "✓ Dungeon AI build complete! Run with: ./$(TARGET_DUNGEON)"

# Compile each .cpp file to .o object file
%.o: %.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Clean: remove compiled files
clean:
	rm -f $(OBJECTS_NN) $(OBJECTS_DUNGEON) $(TARGET_NN) $(TARGET_DUNGEON)
	@echo "✓ Cleaned build files"

# Run neural network version
run: $(TARGET_NN)
	./$(TARGET_NN)

# Run dungeon version
dungeon: $(TARGET_DUNGEON)
	./$(TARGET_DUNGEON)

# Run both
run-all: all
	@echo "\n=== Running Neural Network Demo ===\n"
	./$(TARGET_NN)
	@echo "\n\n=== Running Dungeon AI Demo ===\n"
	./$(TARGET_DUNGEON)

# Run with verbose output (useful for debugging)
debug: CXXFLAGS += -g -DDEBUG
debug: clean all
	@echo "Debug build complete"

# Quick build without optimization (faster)
fast: CXXFLAGS = -std=c++11 -Wall
fast: clean all

# Compile only (don't link)
compile: $(OBJECTS_NN) $(OBJECTS_DUNGEON)
	@echo "✓ Compilation complete"

# Show file sizes
size: all
	@echo "Executable sizes:"
	@ls -lh $(TARGET_NN) $(TARGET_DUNGEON) 2>/dev/null || echo "Build first with: make"

# Phony targets (not actual files)
.PHONY: all clean run dungeon run-all debug fast compile size
