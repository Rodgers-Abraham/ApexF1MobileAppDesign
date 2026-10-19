"""
F1 ML Training Pipeline using real historical data from the Ergast API.
Replaces the synthetic data generation with actual race outcomes.
"""
import os
import pickle
import warnings
import numpy as np

warnings.filterwarnings("ignore")  # Suppress some sklearn warnings

from ml.data_fetcher import build_dataset

MODEL_DIR = os.path.dirname(os.path.abspath(__file__))
XGB_PATH = os.path.join(MODEL_DIR, "xgb_model.json")
RF_PATH = os.path.join(MODEL_DIR, "rf_model.pkl")


def train_ensemble(use_real_data: bool = True):
    import pandas as pd
    from sklearn.model_selection import train_test_split, cross_val_score
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.metrics import accuracy_score, classification_report, roc_auc_score
    import xgboost as xgb

    if use_real_data:
        print("Fetching real F1 historical data from Ergast API...")
        try:
            df = build_dataset(start_year=2015)
            print(f"Loaded {len(df)} records from real F1 data.")
        except Exception as e:
            print(f"Failed to fetch real data: {e}")
            print("Falling back to synthetic data generation...")
            df = _generate_synthetic_f1_data()
    else:
        print("Using synthetic data (not recommended for production)...")
        df = _generate_synthetic_f1_data()

    # Feature columns
    feature_cols = ['grid_position', 'constructor_rank', 'average_finish_last_5', 'championship_points', 'home_race']
    X = df[feature_cols]
    y = df['is_winner']

    print(f"Dataset: {len(df)} records, {len(feature_cols)} features")
    print(f"Winner distribution: {y.value_counts().to_dict()}")

    # Split with stratification
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # Handle class imbalance
    scale_pos_weight = (len(y_train) - sum(y_train)) / sum(y_train) if sum(y_train) > 0 else 1.0

    print("Training XGBoost Classifier...")
    xgb_model = xgb.XGBClassifier(
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        scale_pos_weight=scale_pos_weight,
        random_state=42,
        eval_metric='logloss'
    )
    xgb_model.fit(X_train, y_train)

    print("Training Random Forest Classifier...")
    rf_model = RandomForestClassifier(
        n_estimators=150,
        max_depth=6,
        class_weight='balanced',
        random_state=42
    )
    rf_model.fit(X_train, y_train)

    # Evaluate ensemble
    xgb_probs = xgb_model.predict_proba(X_test)[:, 1]
    rf_probs = rf_model.predict_proba(X_test)[:, 1]
    ensemble_preds = (xgb_probs + rf_probs) / 2
    y_pred_binary = (ensemble_preds >= 0.5).astype(int)

    accuracy = accuracy_score(y_test, y_pred_binary)
    try:
        auc = roc_auc_score(y_test, ensemble_preds)
    except ValueError:
        auc = 0.0

    print(f"\n{'='*50}")
    print(f"Ensemble Model Evaluation:")
    print(f"  Accuracy: {accuracy * 100:.2f}%")
    print(f"  AUC-ROC:  {auc:.4f}")
    print(f"{'='*50}\n")
    print("Classification Report:")
    print(classification_report(y_test, y_pred_binary, target_names=["Loser", "Winner"]))

    # Save models
    print(f"Saving XGBoost model to {XGB_PATH}...")
    xgb_model.save_model(XGB_PATH)

    print(f"Saving Random Forest model to {RF_PATH}...")
    with open(RF_PATH, 'wb') as f:
        pickle.dump(rf_model, f)

    print("Model training pipeline complete!")
    return {'accuracy': accuracy, 'auc': auc}


def _generate_synthetic_f1_data(num_samples=5000):
    """Legacy fallback: Generates realistic synthetic F1 race telemetry for training."""
    import numpy as np
    import pandas as pd

    np.random.seed(42)

    grid = np.random.randint(1, 21, size=num_samples)
    constructor = np.random.randint(1, 11, size=num_samples)
    avg_finish = grid * 0.7 + np.random.normal(2, 1.5, size=num_samples)
    avg_finish = np.clip(avg_finish, 1.0, 20.0)
    points = (11 - constructor) * 35 + np.random.normal(50, 30, size=num_samples)
    points = np.clip(points, 0, 450)
    home_race = np.random.choice([0, 1], size=num_samples, p=[0.9, 0.1])

    df = pd.DataFrame({
        'grid_position': grid,
        'constructor_rank': constructor,
        'average_finish_last_5': avg_finish,
        'championship_points': points,
        'home_race': home_race
    })

    win_probability = (
        (21 - grid) * 2.5 +
        (11 - constructor) * 2.0 +
        (points / 10.0) -
        (avg_finish * 2.0) +
        (home_race * 5.0)
    )
    win_probability += np.random.normal(0, 1.5, size=num_samples)
    threshold = np.percentile(win_probability, 95)
    df['is_winner'] = (win_probability >= threshold).astype(int)

    return df


if __name__ == "__main__":
    train_ensemble(use_real_data=True)
