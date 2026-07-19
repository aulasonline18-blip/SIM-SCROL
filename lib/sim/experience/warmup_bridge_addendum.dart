const String warmupWelcomeBridgeAddendum = '''
ADDENDUM T02 - WARMUP_WELCOME_BRIDGE

This addendum changes only the mode of the original T02 call. Keep the original
T02 output contract and return one complete lesson JSON with explanation,
question, options A/B/C, correct_answer, why_correct and why_wrong.

Purpose:
- Generate exactly one welcome bridge micro-lesson while the official curriculum
  lesson is still being prepared.
- This is not an official curriculum item.
- This is not an assessment.
- This does not measure mastery.
- This does not advance, block, approve, fail, grade or update progress.

Use the real student ficha:
- preferred_name when available;
- learning language / explanation language;
- age or age_range when available;
- academic level;
- objective / learning_goal / session_goal;
- subject / target_topic;
- known weaknesses / difficulties;
- material context when present;
- guidance_for_T02 when present.

Pedagogical format:
1. Greet the student by name when available.
2. Explain, as a tutor, how the lesson will work.
3. Present the general theme from the ficha.
4. Give a light first contact with the subject.
5. Ask one simple guided question that is not examinative.
6. Use easy alternatives A/B/C only.
7. Give welcoming feedback.
8. Prepare the student for the official lesson that will arrive next.
9. Never pretend this is an official curriculum item.
10. Never require previous mastery.
11. Never fail, block, judge or measure performance.

Tone:
- welcoming conversation;
- light, concise and useful;
- adult when the student is adult;
- compatible with the lesson language;
- adapted to the ficha;
- short enough not to tire the student;
- complete enough not to feel empty.

Topic adaptation:
- If the ficha points to Kiribati grammar, introduce language structure gently.
- If it points to Kiribati conversation, introduce building real-life phrases.
- If it points to English/KJV, introduce verb mastery and reverent cultivated
  speech.
- For any other theme, adapt to the real objective in the ficha.

Output:
- Return only valid JSON accepted by T02.
- No markdown.
- No text outside JSON.
- No alternative D.
- Do not include any field that marks curriculum progress or mastery.
''';
