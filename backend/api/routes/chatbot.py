from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from services.gemini_pool import gemini_pool
# We will import our authentication helper once created
# For now, we stub or use a dependency placeholder

router = APIRouter()

class ChatPart(BaseModel):
  text: str

class ChatMessage(BaseModel):
  role: str
  parts: List[ChatPart]

class ChatRequest(BaseModel):
  message: str
  history: Optional[List[ChatMessage]] = []

class ChatResponse(BaseModel):
  response: str

F1_SYSTEM_INSTRUCTION = """You are F1-IQ, a premium AI chatbot assistant built specifically for Formula 1 fans. 
Your main responsibilities are:
1. Provide accurate, citation-backed answers about Formula 1 history, rules, schedules, constructor details, driver statistics, and telemetry.
2. Under NO circumstances should you answer questions unrelated to Formula 1. This includes other motorsports (e.g., NASCAR, MotoGP, IndyCar, Formula E) unless the user is explicitly asking to compare them to F1 rules or speeds.
3. If a user asks about an off-topic subject (such as cooking recipes, programming help, general history, non-F1 sports, pop culture, etc.), you must politely reject the request. Explain that you are programmed strictly as an F1 assistant, and prompt the user to ask an F1-related question instead. Keep your response brief, engaging, and professional.
4. When citing data or statistics (e.g. race results, championship standings), include a small markdown footnote or inline citation referencing your historical source database (e.g., [Ergast API] or [OpenF1 Telemetry]).
5. Maintain a modern, passionate, and racing-oriented tone.
"""

@router.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
  if not request.message.strip():
    raise HTTPException(status_code=400, detail="Message cannot be empty")
  
  # Format contents list from history + new user message
  contents = []
  
  # Add past history
  if request.history:
    for msg in request.history:
      contents.append({
        "role": msg.role,
        "parts": [{"text": part.text} for part in msg.parts]
      })
      
  # Append current message
  contents.append({
    "role": "user",
    "parts": [{"text": request.message}]
  })

  try:
    response_text = gemini_pool.generate_content(
      contents=contents,
      system_instruction=F1_SYSTEM_INSTRUCTION,
      temperature=0.3
    )
    return ChatResponse(response=response_text)
  except Exception as e:
    raise HTTPException(
      status_code=500,
      detail={"error": f"Failed to generate response: {str(e)}", "code": "CHAT_GENERATION_FAILED"}
    )
