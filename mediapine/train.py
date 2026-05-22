import pandas as pd
import numpy as np
import joblib
import matplotlib.pyplot as plt

from sklearn.model_selection import (
    train_test_split,
    cross_val_score
)

from sklearn.preprocessing import (
    StandardScaler,
    label_binarize
)

from sklearn.svm import SVC
from sklearn.ensemble import RandomForestClassifier
from sklearn.neighbors import KNeighborsClassifier

from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    confusion_matrix,
    classification_report,
    ConfusionMatrixDisplay,
    roc_auc_score,
    roc_curve,
    auc
)

# =====================================================
# LOAD DATA
# =====================================================

df = pd.read_csv("data.csv", header=None)

# =====================================================
# SHUFFLE DATA
# =====================================================

df = df.sample(frac=1, random_state=42).reset_index(drop=True)

# =====================================================
# SPLIT X y
# =====================================================

X = df.iloc[:, 1:]
y = df.iloc[:, 0]

# =====================================================
# DATASET INFO
# =====================================================

print("\n===================================")
print("DATASET INFO")
print("===================================")

print("Total samples:", len(df))

print("\nClass distribution:")
print(y.value_counts())

# =====================================================
# TRAIN TEST SPLIT
# =====================================================

X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.2,
    random_state=42,
    stratify=y
)

# =====================================================
# SCALE DATA
# =====================================================

scaler = StandardScaler()

X_train = scaler.fit_transform(X_train)
X_test = scaler.transform(X_test)

# =====================================================
# MODELS
# =====================================================

models = {
    "SVM": SVC(
        kernel='rbf',
        probability=True
    ),

    "RandomForest": RandomForestClassifier(
        n_estimators=100,
        random_state=42
    ),

    "KNN": KNeighborsClassifier(
        n_neighbors=5
    )
}

# =====================================================
# RESULT STORAGE
# =====================================================

results = []

best_model = None
best_acc = 0

# =====================================================
# LABEL BINARIZE FOR ROC-AUC
# =====================================================

classes = np.unique(y)

y_test_bin = label_binarize(
    y_test,
    classes=classes
)

# =====================================================
# TRAIN & EVALUATE
# =====================================================

for name, model in models.items():

    print("\n===================================")
    print("MODEL:", name)
    print("===================================")

    # =================================================
    # TRAIN
    # =================================================

    model.fit(X_train, y_train)

    # =================================================
    # PREDICT
    # =================================================

    y_pred = model.predict(X_test)

    # =================================================
    # METRICS
    # =================================================

    acc = accuracy_score(y_test, y_pred)

    precision = precision_score(
        y_test,
        y_pred,
        average='weighted'
    )

    recall = recall_score(
        y_test,
        y_pred,
        average='weighted'
    )

    f1 = f1_score(
        y_test,
        y_pred,
        average='weighted'
    )

    # =================================================
    # CROSS VALIDATION
    # =================================================

    cv_scores = cross_val_score(
        model,
        scaler.transform(X),
        y,
        cv=5
    )

    cv_mean = np.mean(cv_scores)

    # =================================================
    # ROC-AUC
    # =================================================

    y_prob = model.predict_proba(X_test)

    roc_auc = roc_auc_score(
        y_test_bin,
        y_prob,
        multi_class='ovr'
    )

    # =================================================
    # PRINT METRICS
    # =================================================

    print("Accuracy :", round(acc, 4))
    print("Precision:", round(precision, 4))
    print("Recall   :", round(recall, 4))
    print("F1-score :", round(f1, 4))
    print("CrossVal :", round(cv_mean, 4))
    print("ROC-AUC  :", round(roc_auc, 4))

    # =================================================
    # CONFUSION MATRIX
    # =================================================

    cm = confusion_matrix(y_test, y_pred)

    print("\nCONFUSION MATRIX")
    print(cm)

    # =================================================
    # CLASSIFICATION REPORT
    # =================================================

    print("\nCLASSIFICATION REPORT")

    print(classification_report(
        y_test,
        y_pred
    ))

    # =================================================
    # PLOT CONFUSION MATRIX
    # =================================================

    plt.figure(figsize=(10, 10))

    disp = ConfusionMatrixDisplay(
        confusion_matrix=cm
    )

    disp.plot()

    plt.title(f"Confusion Matrix - {name}")

    plt.show()

    # =================================================
    # ROC CURVE
    # =================================================

    plt.figure(figsize=(8, 8))

    for i in range(len(classes)):

        fpr, tpr, _ = roc_curve(
            y_test_bin[:, i],
            y_prob[:, i]
        )

        roc_value = auc(fpr, tpr)

        plt.plot(
            fpr,
            tpr,
            label=f"{classes[i]} AUC={roc_value:.2f}"
        )

    plt.plot([0, 1], [0, 1], linestyle='--')

    plt.xlabel("False Positive Rate")
    plt.ylabel("True Positive Rate")

    plt.title(f"ROC Curve - {name}")

    plt.legend()

    plt.show()

    # =================================================
    # SAVE RESULT
    # =================================================

    results.append({
        "Model": name,
        "Accuracy": acc,
        "Precision": precision,
        "Recall": recall,
        "F1-score": f1,
        "CrossVal": cv_mean,
        "ROC-AUC": roc_auc
    })

    # =================================================
    # SAVE BEST MODEL
    # =================================================

    if acc > best_acc:

        best_acc = acc
        best_model = model

# =====================================================
# FINAL RESULT
# =====================================================

result_df = pd.DataFrame(results)

print("\n===================================")
print("FINAL RESULT")
print("===================================")

print(result_df)

# =====================================================
# SAVE MODEL
# =====================================================

joblib.dump(best_model, "best_model.pkl")

joblib.dump(scaler, "scaler.pkl")

print("\nBest model saved!")

# =====================================================
# BEST MODEL
# =====================================================

best_row = result_df.loc[
    result_df["Accuracy"].idxmax()
]

print("\n===================================")
print("BEST MODEL")
print("===================================")

print(best_row)