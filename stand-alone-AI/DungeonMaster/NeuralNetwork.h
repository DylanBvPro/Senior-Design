#ifndef NEURAL_NETWORK_H
#define NEURAL_NETWORK_H

#include "Matrix.h"
#include <vector>
#include <cmath>

// Activation functions used in neural network
class ActivationFunction {
public:
    // Sigmoid: maps output to range (0, 1)
    static double sigmoid(double x) {
        return 1.0 / (1.0 + std::exp(-x));
    }

    // Sigmoid derivative for backpropagation
    static double sigmoidDerivative(double output) {
        return output * (1.0 - output);
    }

    // ReLU (Rectified Linear Unit): simple but effective
    static double relu(double x) {
        return x > 0 ? x : 0.0;
    }

    // ReLU derivative
    static double reluDerivative(double x) {
        return x > 0 ? 1.0 : 0.0;
    }

    // Tanh: maps output to range (-1, 1)
    static double tanh(double x) {
        return std::tanh(x);
    }

    // Tanh derivative
    static double tanhDerivative(double output) {
        return 1.0 - (output * output);
    }
};

// Simple feedforward neural network with decision matrix
class NeuralNetwork {
private:
    std::vector<int> layerSizes;           // Sizes of each layer (input, hidden, output)
    std::vector<Matrix> weights;           // Weight matrices between layers
    std::vector<Matrix> biases;            // Bias matrices for each layer
    std::vector<Matrix> layerOutputs;      // Outputs from each layer (for backprop)
    std::vector<Matrix> layerInputs;       // Inputs to each layer (for backprop)
    double learningRate;                   // Controls how much weights change during training
    Matrix decisionMatrix;                 // Stores classification results for analysis

public:
    // Constructor: Create network with specified layer sizes
    // Example: NeuralNetwork({2, 4, 4, 1}) creates network with 2 inputs, two hidden layers with 4 neurons, 1 output
    NeuralNetwork(std::vector<int> layers, double lr = 0.01);

    // Forward propagation: pass input through network to get output
    // Input: vector of input values
    // Returns: output from the final layer
    Matrix feedForward(const Matrix& input);

    // Backward propagation: train network by adjusting weights based on error
    // Input: training input and expected output
    // Trains the network to reduce error
    void backpropagate(const Matrix& input, const Matrix& target);

    // Train network on a dataset
    // inputs: vector of input matrices
    // targets: vector of target output matrices
    // epochs: number of times to go through the training data
    void train(const std::vector<Matrix>& inputs, const std::vector<Matrix>& targets, int epochs);

    // Predict output for given input
    // Returns: matrix containing network prediction
    Matrix predict(const Matrix& input);

    // Decision matrix functions - stores and analyzes classification decisions
    // Update decision matrix with classification result
    void updateDecisionMatrix(const Matrix& prediction, const Matrix& actual, int classIndex);

    // Get the decision matrix (confusion matrix format)
    Matrix getDecisionMatrix() const { return decisionMatrix; }

    // Print decision matrix summary
    void printDecisionMatrix() const;

    // Calculate accuracy from decision matrix
    double calculateAccuracy() const;

    // Get detailed network information
    void printNetworkInfo() const;

    // Set learning rate
    void setLearningRate(double lr) { learningRate = lr; }

private:
    // Apply activation function to matrix values
    // Used after computing layer outputs
    void applyActivation(Matrix& matrix);

    // Apply activation derivative to matrix
    // Used during backpropagation
    void applyActivationDerivative(Matrix& matrix);
};

#endif // NEURAL_NETWORK_H
