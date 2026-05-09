import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.svm import SVC
import joblib

# đọc data
df = pd.read_csv("data.csv", header=None)

X = df.iloc[:, 1:]
y = df.iloc[:, 0]

# chia data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)

# train
model = SVC(kernel='rbf')
model.fit(X_train, y_train)

# lưu model
joblib.dump(model, "model.pkl")

print("Accuracy:", model.score(X_test, y_test))