#ifndef MATRIX_H
#define MATRIX_H

#include <vector>
#include <cmath>
#include <random>
#include <iostream>

// Simple Matrix class for neural network operations
class Matrix {
private:
    std::vector<std::vector<double>> data;
    int rows, cols;

public:
    // Constructor: Initialize matrix with given dimensions
    Matrix(int rows, int cols) : rows(rows), cols(cols) {
        data.resize(rows, std::vector<double>(cols, 0.0));
    }

    // Get value at specific position
    double get(int i, int j) const {
        return data[i][j];
    }

    // Set value at specific position
    void set(int i, int j, double value) {
        data[i][j] = value;
    }

    // Get matrix dimensions
    int getRows() const { return rows; }
    int getCols() const { return cols; }

    // Matrix multiplication: this * other
    Matrix multiply(const Matrix& other) const {
        if (cols != other.rows) {
            throw std::invalid_argument("Matrix dimensions do not match for multiplication");
        }
        
        Matrix result(rows, other.cols);
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < other.cols; j++) {
                double sum = 0.0;
                for (int k = 0; k < cols; k++) {
                    sum += data[i][k] * other.get(k, j);
                }
                result.set(i, j, sum);
            }
        }
        return result;
    }

    // Element-wise addition
    Matrix add(const Matrix& other) const {
        if (rows != other.rows || cols != other.cols) {
            throw std::invalid_argument("Matrix dimensions do not match for addition");
        }
        
        Matrix result(rows, cols);
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                result.set(i, j, data[i][j] + other.get(i, j));
            }
        }
        return result;
    }

    // Element-wise subtraction
    Matrix subtract(const Matrix& other) const {
        if (rows != other.rows || cols != other.cols) {
            throw std::invalid_argument("Matrix dimensions do not match for subtraction");
        }
        
        Matrix result(rows, cols);
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                result.set(i, j, data[i][j] - other.get(i, j));
            }
        }
        return result;
    }

    // Element-wise multiplication (Hadamard product)
    Matrix hadamard(const Matrix& other) const {
        if (rows != other.rows || cols != other.cols) {
            throw std::invalid_argument("Matrix dimensions do not match for hadamard product");
        }
        
        Matrix result(rows, cols);
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                result.set(i, j, data[i][j] * other.get(i, j));
            }
        }
        return result;
    }

    // Scalar multiplication
    Matrix scalarMultiply(double scalar) const {
        Matrix result(rows, cols);
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                result.set(i, j, data[i][j] * scalar);
            }
        }
        return result;
    }

    // Transpose the matrix
    Matrix transpose() const {
        Matrix result(cols, rows);
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                result.set(j, i, data[i][j]);
            }
        }
        return result;
    }

    // Randomize matrix values between -1 and 1
    void randomize() {
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_real_distribution<> dis(-1.0, 1.0);
        
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                data[i][j] = dis(gen);
            }
        }
    }

    // Print matrix to console
    void print() const {
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                printf("%.4f ", data[i][j]);
            }
            printf("\n");
        }
    }
};

#endif // MATRIX_H
