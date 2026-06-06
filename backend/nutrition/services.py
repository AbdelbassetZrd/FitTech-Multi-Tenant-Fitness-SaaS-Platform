"""
Nutrition Chatbot AI Service
Uses Gemini API for LLM-powered nutrition advice.
Falls back to a rule-based responder when no API key is set or the API errors.
"""
import json
from typing import Optional, List, Dict
from django.conf import settings
import requests
import logging

logger = logging.getLogger(__name__)


class NutritionChatbotService:
    """Service for handling nutrition chatbot interactions."""

    GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models"

    # gemini-2.5-flash is extremely fast, capable, and has a great free tier
    PRIMARY_MODEL   = "gemini-2.5-flash"
    SECONDARY_MODEL = "gemini-2.5-pro"

    SYSTEM_PROMPT = """You are FitTech AI, a comprehensive fitness and nutrition coach for gym members. Your role is to:

1. **Provide Expert Fitness Advice**: Create structured gym plans and explain exercise techniques.
2. **Provide Nutrition Guidance**: Give advice on diets, macros, and calories.
3. **Answer Questions**: Directly and concisely.

Communication Style (CRITICAL INSTRUCTIONS):
- **EXTREME CONCISENESS**: Give only the raw, necessary information. 
- NO introductory filler words like "Great question!" or "Here is your plan:".
- NO concluding filler like "Let me know if you need more help!".
- If they ask a question, answer it in 1-2 short sentences.
- If they ask for a workout plan or meal plan, use a simple bulleted list with ZERO fluff before or after.
- Get straight to the point. Every word must be essential.

Important: Always prioritize member safety and health for both exercise and nutrition.
"""

    def __init__(self):
        self.api_key = getattr(settings, 'GEMINI_API_KEY', None) or None
        if not self.api_key:
            logger.info("GEMINI_API_KEY not set — using smart fallback mode.")

    # ── Public interface ───────────────────────────────────────────────────────

    def get_nutrition_advice(
        self,
        user_message: str,
        conversation_history: List[Dict],
        user_profile: Optional[Dict] = None,
    ) -> Dict:
        """
        Return a nutrition advice response.

        If a Gemini API key is available it calls the LLM; otherwise it uses the
        built-in keyword-based fallback that still gives sensible answers.

        Returns:
            {
                "success": bool,
                "message": str,
                "tokens_used": int,
                "model": str,
                "error": str | None,
            }
        """
        if self.api_key:
            result = self._call_gemini(user_message, conversation_history, user_profile, self.PRIMARY_MODEL)
            if not result["success"]:
                logger.warning("Primary model failed, trying secondary model.")
                result = self._call_gemini(user_message, conversation_history, user_profile, self.SECONDARY_MODEL)
            if not result["success"]:
                logger.warning("Both Gemini models failed — falling back to local responder.")
                return self._get_fallback_response(user_message, user_profile)
            return result

        return self._get_fallback_response(user_message, user_profile)

    # ── Gemini API call ──────────────────────────────────────────────────────────

    def _call_gemini(
        self,
        user_message: str,
        conversation_history: List[Dict],
        user_profile: Optional[Dict],
        model: str,
    ) -> Dict:
        try:
            url = f"{self.GEMINI_API_URL}/{model}:generateContent?key={self.api_key}"
            
            contents = []
            for msg in conversation_history[-10:]:
                role = "model" if msg["role"] == "assistant" else "user"
                contents.append({
                    "role": role,
                    "parts": [{"text": msg["content"]}]
                })
            
            contents.append({
                "role": "user",
                "parts": [{"text": user_message}]
            })
            
            payload = {
                "systemInstruction": {
                    "role": "user",
                    "parts": [{"text": self._build_system_message(user_profile)}]
                },
                "contents": contents,
                "generationConfig": {
                    "temperature": 0.7,
                    "maxOutputTokens": 1024,
                }
            }

            response = requests.post(
                url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30,
            )

            if response.status_code != 200:
                logger.error(
                    "Gemini API error [%s] model=%s: %s",
                    response.status_code, model, response.text[:300],
                )
                return {
                    "success": False,
                    "message": "",
                    "error": f"API returned status {response.status_code}: {response.text[:200]}",
                }

            data = response.json()
            return {
                "success": True,
                "message": data["candidates"][0]["content"]["parts"][0]["text"],
                "tokens_used": data.get("usageMetadata", {}).get("totalTokenCount", 0),
                "model": model,
            }

        except requests.exceptions.Timeout:
            logger.error("Gemini API timeout (model=%s)", model)
            return {"success": False, "message": "", "error": "API timeout"}
        except requests.exceptions.RequestException as e:
            logger.error("Gemini API request error (model=%s): %s", model, e)
            return {"success": False, "message": "", "error": str(e)}
        except (json.JSONDecodeError, KeyError, IndexError) as e:
            logger.error("Gemini API response parse error (model=%s): %s\nResponse: %s", model, e, response.text[:300])
            return {"success": False, "message": "", "error": str(e)}
        except Exception as e:
            logger.error("Unexpected error calling Gemini (model=%s): %s", model, e)
            return {"success": False, "message": "", "error": str(e)}

    # ── System prompt builder ──────────────────────────────────────────────────

    def _build_system_message(self, user_profile: Optional[Dict]) -> str:
        message = self.SYSTEM_PROMPT
        if user_profile:
            ctx = "\n\nMember Profile for Context:"
            if user_profile.get("age"):
                ctx += f"\n- Age: {user_profile['age']}"
            if user_profile.get("fitness_goal"):
                ctx += f"\n- Fitness Goal: {user_profile['fitness_goal']}"
            if user_profile.get("dietary_preference"):
                ctx += f"\n- Dietary Preference: {user_profile['dietary_preference']}"
            if user_profile.get("allergies"):
                ctx += f"\n- Allergies: {user_profile['allergies']}"
            if user_profile.get("medical_conditions"):
                ctx += f"\n- Medical Conditions: {user_profile['medical_conditions']}"
            if user_profile.get("nutrition_goals"):
                ctx += f"\n- Nutrition Goals: {user_profile['nutrition_goals']}"
            message += ctx
        return message

    # ── Smart fallback ─────────────────────────────────────────────────────────

    def _get_fallback_response(
        self, user_message: str, user_profile: Optional[Dict] = None
    ) -> Dict:
        """
        Keyword-based fallback that returns helpful, specific nutrition advice
        without requiring an AI API key.
        """
        msg = user_message.lower()

        # Map keyword groups → response
        responses = [
            (
                ["after workout", "post workout", "post-workout", "after training", "recovery"],
                "Great question! 🏋️ For post-workout recovery:\n\n"
                "• **Protein** (within 30–60 min): chicken breast, eggs, Greek yogurt, or a protein shake\n"
                "• **Carbs** to replenish glycogen: rice, oats, banana, or sweet potato\n"
                "• **Hydration**: drink 500–750 ml of water immediately after training\n\n"
                "A simple example: grilled chicken + rice + steamed broccoli. "
                "Aim for a 3:1 or 4:1 carb-to-protein ratio for endurance sessions, "
                "or 2:1 for strength training. 💪",
            ),
            (
                ["before workout", "pre workout", "pre-workout", "before training"],
                "For pre-workout fuel ⚡:\n\n"
                "• Eat **1–2 hours before**: complex carbs + moderate protein + low fat\n"
                "• Example: oatmeal with banana and a boiled egg, or whole-grain toast with peanut butter\n"
                "• **30 min before** (if short on time): a banana or a handful of dates for quick energy\n"
                "• Avoid heavy, fatty, or high-fibre meals right before training — they slow digestion.",
            ),
            (
                ["meal plan", "weekly plan", "diet plan", "what to eat", "eating plan"],
                "Here's a simple weekly nutrition framework 📋:\n\n"
                "**Daily targets (moderate activity):**\n"
                "• Protein: 1.6–2.2 g per kg of body weight\n"
                "• Carbs: 4–6 g per kg (adjust for goals)\n"
                "• Fats: 0.8–1.2 g per kg\n\n"
                "**Sample day:**\n"
                "🌅 Breakfast: Eggs + oats + fruit\n"
                "🕐 Snack: Greek yogurt + nuts\n"
                "🌞 Lunch: Grilled chicken + quinoa + salad\n"
                "🕕 Snack: Banana + protein shake\n"
                "🌙 Dinner: Salmon + sweet potato + vegetables\n\n"
                "Would you like me to customise this for your specific goal? 😊",
            ),
            (
                ["protein", "how much protein", "protein intake"],
                "For protein intake 🥩:\n\n"
                "• **Muscle building**: 1.8–2.2 g per kg of body weight\n"
                "• **Weight loss (muscle preservation)**: 2.0–2.4 g per kg\n"
                "• **General fitness**: 1.4–1.6 g per kg\n\n"
                "**Best sources**: chicken, turkey, fish, eggs, Greek yogurt, cottage cheese, legumes, tofu\n\n"
                "Spread intake across 4–5 meals for optimal muscle protein synthesis.",
            ),
            (
                ["calorie", "calories", "how many calories", "caloric"],
                "Calorie needs depend on your goal 📊:\n\n"
                "• **Maintain weight**: Body weight (kg) × 30–33\n"
                "• **Lose fat**: subtract 300–500 kcal from maintenance\n"
                "• **Build muscle**: add 200–300 kcal to maintenance\n\n"
                "For example, an 80 kg person maintaining weight needs roughly **2 400–2 640 kcal/day**.\n\n"
                "Track your intake for 2 weeks and adjust based on results — real data beats estimates!",
            ),
            (
                ["breakfast", "morning meal", "first meal"],
                "A powerful breakfast 🌅:\n\n"
                "• **Protein**: eggs, Greek yogurt, cottage cheese, or a protein shake\n"
                "• **Complex carbs**: oats, whole-grain bread, or fruit\n"
                "• **Healthy fats**: avocado, nuts, or nut butter\n\n"
                "Quick ideas:\n"
                "1. Scrambled eggs + wholegrain toast + avocado\n"
                "2. Overnight oats + berries + chia seeds + almond butter\n"
                "3. Greek yogurt parfait with granola and banana",
            ),
            (
                ["water", "hydration", "hydrate", "drink water", "how much water"],
                "Hydration guide 💧:\n\n"
                "• **Baseline**: 35 ml per kg of body weight per day\n"
                "• **Training days**: add 500–750 ml per hour of exercise\n"
                "• **Tip**: if your urine is light yellow, you're well hydrated\n\n"
                "Best practice: drink 400–600 ml of water 2 hours before training, "
                "150–250 ml every 15–20 min during, and 500 ml immediately after.",
            ),
            (
                ["weight loss", "lose weight", "lose fat", "fat loss", "cut"],
                "Effective fat-loss nutrition 🔥:\n\n"
                "• **Calorie deficit**: 300–500 kcal below maintenance (no crash diets!)\n"
                "• **High protein**: 2.0–2.4 g/kg to preserve muscle\n"
                "• **Fibre-rich foods**: vegetables, legumes, oats — keep you full longer\n"
                "• **Limit**: ultra-processed foods, sugary drinks, alcohol\n\n"
                "Sustainable rate: 0.5–1 kg per week. Faster is not better — it risks muscle loss.",
            ),
            (
                ["muscle", "muscle gain", "bulk", "build muscle", "mass"],
                "Muscle-building nutrition 💪:\n\n"
                "• **Calorie surplus**: +200–300 kcal above maintenance\n"
                "• **Protein**: 1.8–2.2 g/kg — the non-negotiable\n"
                "• **Carbs**: your main energy source — rice, oats, potatoes, fruit\n"
                "• **Meal timing**: protein every 3–4 hours; post-workout essential\n\n"
                "Key foods: eggs, chicken, beef, fish, dairy, legumes, oats, rice, nuts.",
            ),
            (
                ["vegetarian", "vegan", "plant-based", "no meat"],
                "Plant-based nutrition tips 🌱:\n\n"
                "• **Protein sources**: lentils, chickpeas, tofu, tempeh, edamame, quinoa, seitan\n"
                "• **Combine proteins**: rice + beans, hummus + whole grain — complete amino acids\n"
                "• **Watch**: vitamin B12, iron, zinc, omega-3, and vitamin D (supplement if needed)\n"
                "• **Aim for**: 1.8–2.0 g protein/kg — slightly higher than omnivores to offset lower bioavailability",
            ),
            (
                ["supplement", "supplements", "creatine", "whey", "bcaa", "omega"],
                "Evidence-based supplements 💊:\n\n"
                "**Tier 1 (well-researched, effective):**\n"
                "• **Creatine monohydrate**: 3–5 g/day — strength & muscle gains\n"
                "• **Protein powder**: convenient way to hit protein targets\n"
                "• **Vitamin D** + **Omega-3**: general health, especially if diet is limited\n\n"
                "**Tier 2 (moderate evidence):**\n"
                "• **Caffeine**: performance boost pre-workout\n"
                "• **Beta-alanine**: reduces fatigue in high-intensity efforts\n\n"
                "Skip anything with proprietary blends or miracle claims — food first, supplements second.",
            ),
        ]

        for keywords, reply in responses:
            if any(kw in msg for kw in keywords):
                return {
                    "success": True,
                    "message": reply,
                    "tokens_used": 0,
                    "model": "fallback-mode",
                }

        # Generic helpful response
        return {
            "success": True,
            "message": (
                "Great nutrition question! 🥗 Here are some universal principles:\n\n"
                "• **Eat whole foods** most of the time — vegetables, lean proteins, complex carbs, healthy fats\n"
                "• **Stay hydrated** — aim for 35 ml per kg of body weight daily\n"
                "• **Don't skip meals** — consistent eating stabilises energy and supports metabolism\n"
                "• **Sleep & recovery** matter as much as food — aim for 7–9 hours\n\n"
                "Feel free to ask me something more specific, like:\n"
                "- *'What should I eat after a workout?'*\n"
                "- *'How much protein do I need?'*\n"
                "- *'Give me a weekly meal plan'*"
            ),
            "tokens_used": 0,
            "model": "fallback-mode",
        }
