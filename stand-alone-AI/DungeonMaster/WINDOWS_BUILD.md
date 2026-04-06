# Windows Compilation Guide

## Compilation Options for Windows

### Option 1: Using Visual Studio (Recommended for Windows)

1. **Create a new C++ project**:
   - Open Visual Studio
   - File → New → Project
   - Select "Empty C++ Project"
   - Name it "NeuralNetwork"

2. **Add files to project**:
   - Copy all `.cpp` and `.h` files to project folder
   - In Visual Studio: Project → Add Existing Item
   - Select all `.cpp` and `.h` files

3. **Build**:
   - Press `Ctrl + Shift + B` or Build → Build Solution
   - Executable will be in `x64\Debug` or `x64\Release` folder

4. **Run**:
   - Press `Ctrl + F5` or Debug → Start Without Debugging

### Option 2: Using MinGW (g++ compiler)

1. **Install MinGW** (if not already installed):
   - Download from: https://www.mingw-w64.org/
   - Or use: https://sourceforge.net/projects/mingw-w64/
   - Add to PATH during installation

2. **Verify installation**:
   ```bash
   g++ --version
   ```

3. **Compile**:
   ```bash
   g++ -std=c++11 -O2 -o neural_network.exe main.cpp NeuralNetwork.cpp
   ```

   **Compile Dungeon AI demo**:
   ```bash
   g++ -std=c++11 -O2 -o dungeon_master.exe dungeon_main.cpp DungeonAI.cpp NeuralNetwork.cpp GraphUtils.cpp PopupUI.cpp
   ```

4. **Run**:
   ```bash
   neural_network.exe
   ```

   **Run Dungeon AI demo**:
   ```bash
   dungeon_master.exe
   ```

### Option 3: Windows-Only Support Notice

This guide is intended for Windows workflows only.
If you want to run on other platforms, you must adapt setup, build tools, and commands yourself.

### Option 4: Using MinGW with Makefile

1. **Install MinGW and make**:
   - Download: http://mingw.org/ or https://www.mingw-w64.org/
   - Install make separately from http://gnuwin32.sourceforge.net/packages/make.htm
   - Add both to PATH

2. **Compile**:
   ```bash
   make
   ```

3. **Run**:
   ```bash
   make run
   ```
   ```bash
   make dungeon
   ```

## Quick Start (Windows Command Prompt)

```bash
# Navigate to project directory
cd C:\path\to\DugeonMaster

# Compile with g++
g++ -std=c++11 -O2 -o neural_network.exe main.cpp NeuralNetwork.cpp

# Compile Dungeon AI demo
g++ -std=c++11 -O2 -o dungeon_master.exe dungeon_main.cpp DungeonAI.cpp NeuralNetwork.cpp GraphUtils.cpp PopupUI.cpp

# Run
neural_network.exe

# Run Dungeon AI demo
dungeon_master.exe
```

## If You Get Compiler Not Found Error

1. **Check if g++ is installed**:
   ```bash
   where g++
   ```

2. **If not found, install MinGW**:
   - Download MinGW-w64 installer
   - Run installer
   - Choose: posix threading, x86_64 architecture
   - Install to: `C:\MinGW` or simpler path
   - Add `C:\MinGW\bin` to Windows PATH

3. **Verify installation**:
   ```bash
   g++ --version
   ```

## Troubleshooting

### "g++ is not recognized"
- Add MinGW bin folder to PATH
- Or use full path: `C:\MinGW\bin\g++.exe`

### "cannot find -lm"
- Not a problem in Windows, just compile normally

### Slow compilation
- Add `-O2` for optimizations (included in commands above)

### Program runs but produces no output
- Scroll up in terminal to see output
- Or redirect to file: `neural_network.exe > output.txt`

## Running from VS Code

1. **Install VS Code C++**: 
   - Install "C/C++" extension (Microsoft)
   - Install MinGW if not present

2. **Create `.vscode/tasks.json`**:
   ```json
   {
       "version": "2.0.0",
       "tasks": [
           {
               "label": "Build",
               "type": "shell",
               "command": "g++",
               "args": [
                   "-std=c++11",
                   "-O2",
                   "-o",
                   "neural_network.exe",
                   "main.cpp",
                   "NeuralNetwork.cpp"
               ],
               "group": {
                   "kind": "build",
                   "isDefault": true
               }
           },
           {
               "label": "Run",
               "type": "shell",
               "command": ".\\neural_network.exe",
               "dependsOn": ["Build"],
               "problemMatcher": []
           }
       ]
   }
   ```

3. **Build and Run**:
   - Press `Ctrl + Shift + B` to build
   - Press `Ctrl + Shift + D` then click Run

## Performance Build

For faster execution, compile with optimizations:

```bash
g++ -std=c++11 -O3 -march=native -o neural_network.exe main.cpp NeuralNetwork.cpp
```

## Debug Build

For debugging with gdb:

```bash
g++ -std=c++11 -g -o neural_network_debug.exe main.cpp NeuralNetwork.cpp

# Then debug with gdb or VS Code debugger
```
