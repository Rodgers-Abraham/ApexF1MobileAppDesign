import os
import random
import time
import logging
import requests
from core.config import get_settings

logger = logging.getLogger(__name__)

class GeminiPool:
    def __init__(self):
        settings = get_settings()
        self.keys = settings.gemini_keys if isinstance(settings.gemini_keys, list) else []
        self.openrouter_key = settings.openrouter_key
        self.cooldowns = {}  # key -> cooldown_end_timestamp
        self.cooldown_duration = 300  # 5 minutes

        # Also support comma-separated in environment for backward compat
        env_keys = os.environ.get("GEMINI_KEYS", os.environ.get("GEMINI_KEY", ""))
        if env_keys and not self.keys:
            self.keys = [k.strip() for k in env_keys.split(",") if k.strip()]

        logger.info(f"Initialized GeminiPool with {len(self.keys)} keys. OpenRouter fallback available: {bool(self.openrouter_key)}")

    def _get_active_key(self):
        current_time = time.time()
        active_keys = [k for k in self.keys if self.cooldowns.get(k, 0) < current_time]

        if not active_keys:
            return None

        # Pick a random active key for load balancing
        return random.choice(active_keys)

    def _cooldown_key(self, key):
        logger.warning("Banning/cooldown key for 5 minutes due to API error/rate-limit.")
        self.cooldowns[key] = time.time() + self.cooldown_duration

    def generate_content(self, contents, system_instruction=None, temperature=0.3):
        """
        Generates content using the key pool.
        'contents' matches Gemini API format: [{"role": "user", "parts": [{"text": "..."}]}]
        """
        tried_keys = set()

        while len(tried_keys) < len(self.keys):
            key = self._get_active_key()
            if not key:
                break

            tried_keys.add(key)
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={key}"

            payload = {
                "contents": contents,
                "generationConfig": {
                    "temperature": temperature
                }
            }

            if system_instruction:
                payload["systemInstruction"] = {
                    "parts": [{"text": system_instruction}]
                }

            try:
                response = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=15)

                if response.status_code == 200:
                    data = response.json()
                    # Parse text output from Gemini response structure
                    text = data['candidates'][0]['content']['parts'][0]['text']
                    return text
                elif response.status_code == 429:
                    logger.warning("Gemini API key returned 429 (Rate Limit). Banning key.")
                    self._cooldown_key(key)
                else:
                    logger.error(f"Gemini API returned error {response.status_code}: {response.text}")
                    self._cooldown_key(key)
            except Exception as e:
                logger.error(f"Error calling Gemini API: {e}")
                self._cooldown_key(key)

        # Fallback to OpenRouter
        if self.openrouter_key:
            logger.info("All Gemini keys exhausted or failed. Falling back to OpenRouter...")
            return self._call_openrouter(contents, system_instruction, temperature)

        raise Exception("All Gemini keys exhausted, and no OpenRouter fallback key is configured.")

    def _call_openrouter(self, contents, system_instruction=None, temperature=0.3):
        url = "https://openrouter.ai/api/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.openrouter_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://f1-apex-app.com",  # Required for OpenRouter rankings
            "X-Title": "F1 Apex App"
        }

        # Convert Gemini format to standard OpenAI messages format for OpenRouter
        messages = []
        if system_instruction:
            messages.append({"role": "system", "content": system_instruction})

        for content in contents:
            role = content.get("role", "user")
            text = content.get("parts", [{}])[0].get("text", "")
            messages.append({"role": role, "content": text})

        payload = {
            "model": "google/gemini-1.5-flash",
            "messages": messages,
            "temperature": temperature
        }

        try:
            response = requests.post(url, json=payload, headers=headers, timeout=20)
            if response.status_code == 200:
                data = response.json()
                return data['choices'][0]['message']['content']
            else:
                raise Exception(f"OpenRouter API returned error {response.status_code}: {response.text}")
        except Exception as e:
            logger.error(f"OpenRouter fallback failed: {e}")
            raise e

# Global single instance of the pool
gemini_pool = GeminiPool()
