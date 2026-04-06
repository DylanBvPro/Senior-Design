#include "NeuralNetwork.h"
#include <iostream>

// ============================================================================
// SIMPLE NEURAL NETWORK WITH DECISION MATRIX - DEMONSTRATION
// ============================================================================
// This program demonstrates a simple feedforward neural network that learns
// to classify data. It includes a decision matrix to track classification
// accuracy for each class.
// ============================================================================

int main() {
    std::cout << "=== Simple Neural Network with Decision Matrix ===\n\n";

    // ========================================================================
    // STEP 1: CREATE NEURAL NETWORK
    // ========================================================================
    // Create network with:
    // - 2 inputs (features)
    // - 4 neurons in first hidden layer
    // - 4 neurons in second hidden layer  
    // - 2 outputs (classes)
    // - Learning rate of 0.5 (controls how much weights change each iteration)
    //
    // MODIFICATION: Change layer sizes
    // Example: NeuralNetwork({3, 8, 8, 3}) for 3 inputs, 3 outputs
    NeuralNetwork nn({2, 4, 4, 2}, 0.5);
    
    std::cout << "Neural Network Created\n";
    nn.printNetworkInfo();

    // ========================================================================
    // STEP 2: PREPARE TRAINING DATA
    // ========================================================================
    // Create training data: simple XOR-like problem
    // We'll train the network to distinguish between two classes
    
    std::vector<Matrix> trainingInputs;
    std::vector<Matrix> trainingTargets;

    // Class 0 samples (target: [1, 0])
    Matrix input1(1, 2);
    input1.set(0, 0, 0.0);
    input1.set(0, 1, 0.0);
    trainingInputs.push_back(input1);
    Matrix target1(1, 2);
    target1.set(0, 0, 1.0);
    target1.set(0, 1, 0.0);
    trainingTargets.push_back(target1);

    Matrix input2(1, 2);
    input2.set(0, 0, 0.1);
    input2.set(0, 1, 0.1);
    trainingInputs.push_back(input2);
    trainingTargets.push_back(target1);

    Matrix input3(1, 2);
    input3.set(0, 0, 0.2);
    input3.set(0, 1, 0.0);
    trainingInputs.push_back(input3);
    trainingTargets.push_back(target1);

    // Class 1 samples (target: [0, 1])
    Matrix input4(1, 2);
    input4.set(0, 0, 1.0);
    input4.set(0, 1, 1.0);
    trainingInputs.push_back(input4);
    Matrix target2(1, 2);
    target2.set(0, 0, 0.0);
    target2.set(0, 1, 1.0);
    trainingTargets.push_back(target2);

    Matrix input5(1, 2);
    input5.set(0, 0, 0.9);
    input5.set(0, 1, 1.0);
    trainingInputs.push_back(input5);
    trainingTargets.push_back(target2);

    Matrix input6(1, 2);
    input6.set(0, 0, 1.0);
    input6.set(0, 1, 0.9);
    trainingInputs.push_back(input6);
    trainingTargets.push_back(target2);

    std::cout << "\nTraining data prepared (6 samples, 2 classes)\n";

    // ========================================================================
    // STEP 3: TRAIN THE NETWORK
    // ========================================================================
    // Train for 5000 epochs (iterations through the training data)
    // 
    // MODIFICATION: Adjust training parameters
    // - Increase epochs for better accuracy (e.g., 10000)
    // - Adjust learning rate with nn.setLearningRate(0.1)
    // - Add more training samples for better generalization
    
    nn.train(trainingInputs, trainingTargets, 5000);

    // ========================================================================
    // STEP 4: TEST AND EVALUATE WITH DECISION MATRIX
    // ========================================================================
    std::cout << "\n=== Testing Network ===\n";

    // Reset decision matrix for testing
    Matrix testDecisionMatrix(2, 2);
    for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 2; j++) {
            testDecisionMatrix.set(i, j, 0.0);
        }
    }

    // Test on training data
    for (int i = 0; i < trainingInputs.size(); i++) {
        Matrix prediction = nn.predict(trainingInputs[i]);
        
        // Print prediction
        std::cout << "Input [" << trainingInputs[i].get(0, 0) << ", " 
                  << trainingInputs[i].get(0, 1) << "] -> "
                  << "Output [" << prediction.get(0, 0) << ", " 
                  << prediction.get(0, 1) << "]";
        
        // Determine predicted class
        if (prediction.get(0, 0) > prediction.get(0, 1)) {
            std::cout << " (Class 0)";
        } else {
            std::cout << " (Class 1)";
        }
        std::cout << " - Expected Class ";
        if (trainingTargets[i].get(0, 0) > trainingTargets[i].get(0, 1)) {
            std::cout << "0\n";
        } else {
            std::cout << "1\n";
        }

        // Update decision matrix
        nn.updateDecisionMatrix(prediction, trainingTargets[i], i);
    }

    // ========================================================================
    // STEP 5: DISPLAY DECISION MATRIX
    // ========================================================================
    // The decision matrix (confusion matrix) shows:
    // - Rows: Actual class
    // - Columns: Predicted class
    // - Diagonal elements: Correct predictions
    // - Off-diagonal: Misclassifications
    
    nn.printDecisionMatrix();

    // ========================================================================
    // STEP 6: MAKE PREDICTIONS ON NEW DATA
    // ========================================================================
    std::cout << "\n=== Predictions on New Data ===\n";
    
    Matrix testInput1(1, 2);
    testInput1.set(0, 0, 0.15);
    testInput1.set(0, 1, 0.15);
    Matrix pred1 = nn.predict(testInput1);
    std::cout << "Input [0.15, 0.15]: [" << pred1.get(0, 0) << ", " 
              << pred1.get(0, 1) << "]\n";

    Matrix testInput2(1, 2);
    testInput2.set(0, 0, 0.95);
    testInput2.set(0, 1, 0.95);
    Matrix pred2 = nn.predict(testInput2);
    std::cout << "Input [0.95, 0.95]: [" << pred2.get(0, 0) << ", " 
              << pred2.get(0, 1) << "]\n";

    return 0;
}

/*
===============================================================================
HOW TO MODIFY AND EXPAND THE NEURAL NETWORK
===============================================================================

1. CHANGE NETWORK ARCHITECTURE:
   - Modify layer sizes: NeuralNetwork({inputSize, hidden1, hidden2, ..., outputSize})
   - Add more layers: NeuralNetwork({2, 8, 8, 8, 4, 2}) for deeper network
   - Use more neurons: NeuralNetwork({2, 64, 64, 2}) for more capacity

2. IMPROVE TRAINING:
   - Increase epochs: nn.train(inputs, targets, 10000)
   - Adjust learning rate: nn.setLearningRate(0.1) (lower = slower but more stable)
   - Add more training data for better generalization

3. CHANGE ACTIVATION FUNCTIONS:
   - In applyActivation() and applyActivationDerivative() methods
   - Replace sigmoid with relu: ActivationFunction::relu(output)
   - Or try tanh: ActivationFunction::tanh(output)

4. USE DECISION MATRIX FOR ANALYSIS:
   - Update matrix during testing: nn.updateDecisionMatrix(pred, target, index)
   - Calculate metrics: nn.calculateAccuracy()
   - Visualize results: nn.printDecisionMatrix()

5. ADD REGULARIZATION (prevent overfitting):
   - Apply L2 regularization to weights during training
   - Add dropout layer (randomly deactivate neurons)
   - Use early stopping when validation error increases

6. IMPLEMENT DIFFERENT LOSS FUNCTIONS:
   - Current: Mean Squared Error (MSE)
   - Try: Cross-entropy for classification
   - Or: Mean Absolute Error (MAE)

7. BATCH LEARNING:
   - Update weights after processing multiple samples (batch)
   - Instead of after each sample
   - More stable training, better for larger datasets

8. SAVE/LOAD WEIGHTS:
   - Serialize weights and biases to file
   - Load pre-trained weights without retraining
   - Good for large models or production use

9. ADD MOMENTUM:
   - Accumulate gradient updates over iterations
   - Helps escape local minima
   - Faster convergence

10. FOR MULTI-CLASS CLASSIFICATION:
    - Use softmax activation for output layer
    - Replace sigmoid with softmax
    - Use cross-entropy loss instead of MSE

===============================================================================
*/
