#include "NeuralNetwork.h"
#include <iostream>
#include <cmath>

// Constructor: Initialize network with given layer sizes
NeuralNetwork::NeuralNetwork(std::vector<int> layers, double lr) 
    : layerSizes(layers), learningRate(lr), 
      decisionMatrix(layers.back(), layers.back()) // Decision matrix size = output layer size
{
    // Initialize weights and biases for each layer transition
    // Example: if layers = {2, 4, 1}, we create:
    // - weights[0]: 2x4 (input to first hidden)
    // - weights[1]: 4x1 (hidden to output)
    for (int i = 0; i < layers.size() - 1; i++) {
        // Create weight matrix: rows = current layer size, cols = next layer size
        Matrix w(layers[i], layers[i + 1]);
        w.randomize();
        weights.push_back(w);

        // Create bias matrix: 1 x next layer size
        Matrix b(1, layers[i + 1]);
        b.randomize();
        biases.push_back(b);
    }

    // Initialize decision matrix with zeros
    for (int i = 0; i < decisionMatrix.getRows(); i++) {
        for (int j = 0; j < decisionMatrix.getCols(); j++) {
            decisionMatrix.set(i, j, 0.0);
        }
    }
}

// Forward propagation: pass input through network
Matrix NeuralNetwork::feedForward(const Matrix& input) {
    Matrix current = input;
    layerInputs.clear();
    layerOutputs.clear();

    // Process through each layer
    for (int i = 0; i < weights.size(); i++) {
        layerInputs.push_back(current);

        // Compute: output = input * weights + bias
        Matrix z = current.multiply(weights[i]);
        z = z.add(biases[i]);

        // Apply activation function
        applyActivation(z);
        layerOutputs.push_back(z);

        current = z;
    }

    return current;
}

// Apply sigmoid activation to all elements in matrix
void NeuralNetwork::applyActivation(Matrix& matrix) {
    for (int i = 0; i < matrix.getRows(); i++) {
        for (int j = 0; j < matrix.getCols(); j++) {
            // Using sigmoid as default activation
            matrix.set(i, j, ActivationFunction::sigmoid(matrix.get(i, j)));
        }
    }
}

// Apply sigmoid derivative to all elements
void NeuralNetwork::applyActivationDerivative(Matrix& matrix) {
    for (int i = 0; i < matrix.getRows(); i++) {
        for (int j = 0; j < matrix.getCols(); j++) {
            matrix.set(i, j, ActivationFunction::sigmoidDerivative(matrix.get(i, j)));
        }
    }
}

// Backpropagation: Train network by adjusting weights
// This implements the backpropagation algorithm to minimize error
void NeuralNetwork::backpropagate(const Matrix& input, const Matrix& target) {
    // First, perform forward pass
    Matrix output = feedForward(input);

    // Calculate output layer error: (predicted - target)
    Matrix error = output.subtract(target);

    // Backpropagate error through each layer (from output to input)
    for (int i = weights.size() - 1; i >= 0; i--) {
        // Preserve current weights for stable error propagation.
        Matrix currentWeights = weights[i];

        // Delta for this layer: error * activation_derivative
        Matrix delta = layerOutputs[i];
        applyActivationDerivative(delta);
        delta = error.hadamard(delta);

        // Parameter update uses learning-rate-scaled delta.
        Matrix gradient = delta.scalarMultiply(learningRate);

        // Calculate weight adjustments: input^T * gradient
        Matrix inputTranspose = layerInputs[i].transpose();
        Matrix weightAdjustment = inputTranspose.multiply(gradient);

        // Update weights and biases
        weights[i] = weights[i].subtract(weightAdjustment);
        biases[i] = biases[i].subtract(gradient);

        // Propagate error to previous layer using unscaled delta and pre-update weights.
        if (i > 0) {
            error = delta.multiply(currentWeights.transpose());
        }
    }
}

// Train network on entire dataset for multiple epochs
void NeuralNetwork::train(const std::vector<Matrix>& inputs, 
                         const std::vector<Matrix>& targets, 
                         int epochs) {
    if (inputs.size() != targets.size()) {
        throw std::invalid_argument("Number of inputs must match number of targets");
    }

    std::cout << "Training neural network for " << epochs << " epochs...\n";

    for (int epoch = 0; epoch < epochs; epoch++) {
        double totalError = 0.0;

        // Train on each sample
        for (int i = 0; i < inputs.size(); i++) {
            backpropagate(inputs[i], targets[i]);

            // Calculate and accumulate error (Mean Squared Error)
            Matrix output = feedForward(inputs[i]);
            for (int j = 0; j < output.getRows(); j++) {
                for (int k = 0; k < output.getCols(); k++) {
                    double diff = output.get(j, k) - targets[i].get(j, k);
                    totalError += diff * diff;
                }
            }
        }

        // Print progress every 500 epochs
        if ((epoch + 1) % 500 == 0) {
            std::cout << "Epoch " << epoch + 1 << " - Error: " << totalError / inputs.size() << "\n";
        }
    }

    std::cout << "Training complete!\n";
}

// Make prediction on input
Matrix NeuralNetwork::predict(const Matrix& input) {
    return feedForward(input);
}

// Update decision matrix with classification result
// This tracks correct/incorrect predictions for each class
void NeuralNetwork::updateDecisionMatrix(const Matrix& prediction, 
                                        const Matrix& actual, 
                                        int classIndex) {
    // Find predicted class (highest output value)
    int predictedClass = 0;
    double maxValue = prediction.get(0, 0);
    for (int i = 1; i < prediction.getCols(); i++) {
        if (prediction.get(0, i) > maxValue) {
            maxValue = prediction.get(0, i);
            predictedClass = i;
        }
    }

    // Find actual class
    int actualClass = 0;
    maxValue = actual.get(0, 0);
    for (int i = 1; i < actual.getCols(); i++) {
        if (actual.get(0, i) > maxValue) {
            maxValue = actual.get(0, i);
            actualClass = i;
        }
    }

    // Update decision matrix at [actual][predicted] position
    double currentValue = decisionMatrix.get(actualClass, predictedClass);
    decisionMatrix.set(actualClass, predictedClass, currentValue + 1.0);
}

// Print decision matrix and statistics
void NeuralNetwork::printDecisionMatrix() const {
    std::cout << "\n=== Decision Matrix (Confusion Matrix) ===\n";
    std::cout << "Rows = Actual Class, Columns = Predicted Class\n\n";
    decisionMatrix.print();
    std::cout << "\nAccuracy: " << calculateAccuracy() * 100 << "%\n";
}

// Calculate accuracy from decision matrix
// Accuracy = (correct predictions) / (total predictions)
double NeuralNetwork::calculateAccuracy() const {
    double correct = 0.0;
    double total = 0.0;

    for (int i = 0; i < decisionMatrix.getRows(); i++) {
        for (int j = 0; j < decisionMatrix.getCols(); j++) {
            double value = decisionMatrix.get(i, j);
            total += value;
            if (i == j) {
                correct += value;
            }
        }
    }

    return total == 0.0 ? 0.0 : correct / total;
}

// Print network structure and weights
void NeuralNetwork::printNetworkInfo() const {
    std::cout << "\n=== Neural Network Info ===\n";
    std::cout << "Network Structure: ";
    for (int i = 0; i < layerSizes.size(); i++) {
        std::cout << layerSizes[i];
        if (i < layerSizes.size() - 1) std::cout << " -> ";
    }
    std::cout << "\n";
    std::cout << "Learning Rate: " << learningRate << "\n";
    std::cout << "Number of Weight Matrices: " << weights.size() << "\n\n";

    for (int i = 0; i < weights.size(); i++) {
        std::cout << "Layer " << i << " Weights (" << weights[i].getRows() 
                  << "x" << weights[i].getCols() << "):\n";
        weights[i].print();
        std::cout << "\nLayer " << i << " Biases:\n";
        biases[i].print();
    }
}
