import os
import pickle
from ml.train import train_ensemble, XGB_PATH, RF_PATH

class MLPredictorService:
  def __init__(self):
    self.xgb_model = None
    self.rf_model = None
    self._load_models()

  def _load_models(self):
    # Self-heal / train if models do not exist yet
    if not os.path.exists(XGB_PATH) or not os.path.exists(RF_PATH):
      print("ML models not found. Triggering training pipeline...")
      try:
        train_ensemble()
      except Exception as e:
        print(f"Error training models automatically: {e}")
        return

    # Heavy imports moved inside method to support quick load
    import xgboost as xgb

    try:
      # Load XGBoost model
      self.xgb_model = xgb.XGBClassifier()
      self.xgb_model.load_model(XGB_PATH)
      
      # Load Random Forest model
      with open(RF_PATH, 'rb') as f:
        self.rf_model = pickle.load(f)
        
      print("ML models loaded successfully.")
    except Exception as e:
      print(f"Error loading F1 prediction models: {e}")

  def predict_probabilities(self, race_features: list) -> list:
    """
    Predict win probability for a list of drivers.
    """
    if not self.xgb_model or not self.rf_model:
      self._load_models()
      if not self.xgb_model or not self.rf_model:
        raise Exception("ML Models are unavailable. Please ensure training completed successfully.")

    # Heavy imports moved inside method
    import pandas as pd
    import numpy as np

    df_input = pd.DataFrame(race_features)

    # Ensure both 'average_finish' and 'average_finish_last_5' exist in df_input
    if 'average_finish' in df_input.columns and 'average_finish_last_5' not in df_input.columns:
        df_input['average_finish_last_5'] = df_input['average_finish']
    if 'average_finish_last_5' in df_input.columns and 'average_finish' not in df_input.columns:
        df_input['average_finish'] = df_input['average_finish_last_5']

    # Match XGBoost model's feature names
    xgb_features = self.xgb_model.get_booster().feature_names if (self.xgb_model and hasattr(self.xgb_model, 'get_booster') and self.xgb_model.get_booster().feature_names) else ['grid_position', 'constructor_rank', 'average_finish_last_5', 'championship_points', 'home_race']
    X_xgb = df_input[xgb_features]

    # Match Random Forest model's feature names
    if hasattr(self.rf_model, 'feature_names_in_'):
        rf_features = list(self.rf_model.feature_names_in_)
        X_rf = df_input[rf_features]
    else:
        X_rf = X_xgb

    # Predict probabilities from both classifiers
    xgb_probs = self.xgb_model.predict_proba(X_xgb)[:, 1]
    rf_probs = self.rf_model.predict_proba(X_rf)[:, 1]

    # Average ensemble
    ensemble_probs = (xgb_probs + rf_probs) / 2.0
    
    # Normalize probabilities to sum up to 100% across the active grid simulation
    prob_sum = sum(ensemble_probs)
    if prob_sum > 0:
      normalized_probs = [p / prob_sum for p in ensemble_probs]
    else:
      normalized_probs = [1.0 / len(ensemble_probs) for _ in ensemble_probs]

    results = []
    for idx, row in df_input.iterrows():
      results.append({
        'driver_name': row['driver_name'],
        'probability': round(normalized_probs[idx] * 100, 1)
      })

    # Sort from highest win probability to lowest
    results.sort(key=lambda x: x['probability'], reverse=True)
    return results

# Global prediction service instance
ml_predictor = MLPredictorService()
