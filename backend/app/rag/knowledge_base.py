"""
RAG Knowledge Base — Static Clinical Content

LEARN — What this file is:
───────────────────────────
This is the "library" that the RAG system retrieves from.
Every document here is a chunk of clinical content — exact questionnaire
questions, scoring thresholds, DSM-5 criteria summaries, crisis text.

WHY we store it here and not just in the LLM's system prompt:
   The system prompt has a token limit. We can't fit all of GAD-7, PHQ-9,
   DASS, ASRS, and DSM-5 criteria in one prompt.
   Instead we store everything here and only RETRIEVE the relevant chunks
   at query time — injecting only what's needed into the context.

WHY exact wording matters:
   These are real, scientifically validated questionnaires.
   The scoring depends on exact question wording. If the LLM paraphrases
   "Nearly every day" as "Almost always", the score interpretation breaks.
   We keep exact wording here. The LLM wraps it in natural language
   but the core question text comes from this file.

STRUCTURE of each document:
   - content: the exact text chunk
   - category: which instrument it belongs to
   - metadata: question number, score range, thresholds etc
"""

from dataclasses import dataclass, field


@dataclass
class KnowledgeChunk:
    content: str
    category: str          # 'gad7' | 'phq9' | 'dass' | 'crisis' | 'dsm5' | 'scoring'
    metadata: dict = field(default_factory=dict)


# ── GAD-7 (Generalized Anxiety Disorder) ─────────────────────────────────────
# LEARN: GAD-7 has 7 questions, each scored 0-3
# Total score: 0-21
# Thresholds: 5=mild, 10=moderate, 15=severe
# Time window: "Over the last 2 weeks"

GAD7_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "GAD-7 Introduction: The GAD-7 measures anxiety severity over the past 2 weeks. "
            "Each question is scored: Not at all=0, Several days=1, "
            "More than half the days=2, Nearly every day=3."
        ),
        category="gad7",
        metadata={"type": "intro", "score_range": "0-21",
                  "thresholds": {"mild": 5, "moderate": 10, "severe": 15}},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 Question 1: Feeling nervous, anxious, or on edge. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="gad7",
        metadata={"question": 1, "construct": "anxiety_nervousness"},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 Question 2: Not being able to stop or control worrying. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="gad7",
        metadata={"question": 2, "construct": "uncontrollable_worry"},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 Question 3: Worrying too much about different things. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="gad7",
        metadata={"question": 3, "construct": "excessive_worry"},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 Question 4: Trouble relaxing. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="gad7",
        metadata={"question": 4, "construct": "tension_relaxation"},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 Question 5: Being so restless that it is hard to sit still. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="gad7",
        metadata={"question": 5, "construct": "restlessness"},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 Question 6: Becoming easily annoyed or irritable. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="gad7",
        metadata={"question": 6, "construct": "irritability"},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 Question 7: Feeling afraid as if something awful might happen. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="gad7",
        metadata={"question": 7, "construct": "fear_anticipation"},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 Scoring: Total score 0-4 = Minimal anxiety. "
            "5-9 = Mild anxiety. 10-14 = Moderate anxiety. "
            "15-21 = Severe anxiety. Scores of 10 or above suggest "
            "clinically significant anxiety warranting further evaluation."
        ),
        category="gad7",
        metadata={"type": "scoring"},
    ),
]

# ── PHQ-9 (Patient Health Questionnaire — Depression) ────────────────────────
# LEARN: PHQ-9 has 9 questions, each scored 0-3
# Total score: 0-27
# Thresholds: 5=mild, 10=moderate, 15=moderately severe, 20=severe
# Q9 is the self-harm question — HARDCODED CRISIS RESPONSE if answered > 0
# Time window: "Over the last 2 weeks"

PHQ9_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "PHQ-9 Introduction: The PHQ-9 measures depression severity over the past 2 weeks. "
            "Each question is scored: Not at all=0, Several days=1, "
            "More than half the days=2, Nearly every day=3."
        ),
        category="phq9",
        metadata={"type": "intro", "score_range": "0-27",
                  "thresholds": {"mild": 5, "moderate": 10,
                                 "moderately_severe": 15, "severe": 20}},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 Question 1: Little interest or pleasure in doing things. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3). "
            "This measures anhedonia — loss of pleasure — a core depression symptom."
        ),
        category="phq9",
        metadata={"question": 1, "construct": "anhedonia"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 Question 2: Feeling down, depressed, or hopeless. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3). "
            "This measures depressed mood — the other core depression symptom."
        ),
        category="phq9",
        metadata={"question": 2, "construct": "depressed_mood"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 Question 3: Trouble falling or staying asleep, or sleeping too much. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="phq9",
        metadata={"question": 3, "construct": "sleep_disturbance"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 Question 4: Feeling tired or having little energy. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="phq9",
        metadata={"question": 4, "construct": "fatigue"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 Question 5: Poor appetite or overeating. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="phq9",
        metadata={"question": 5, "construct": "appetite_change"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 Question 6: Feeling bad about yourself — or that you are a failure "
            "or have let yourself or your family down. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="phq9",
        metadata={"question": 6, "construct": "worthlessness_guilt"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 Question 7: Trouble concentrating on things, such as reading the "
            "newspaper or watching television. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="phq9",
        metadata={"question": 7, "construct": "concentration"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 Question 8: Moving or speaking so slowly that other people could "
            "have noticed. Or the opposite — being so fidgety or restless that you "
            "have been moving around a lot more than usual. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3)."
        ),
        category="phq9",
        metadata={"question": 8, "construct": "psychomotor"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 Question 9 (SAFETY QUESTION): Thoughts that you would be better off "
            "dead or of hurting yourself in some way. "
            "Score options: Not at all (0), Several days (1), "
            "More than half the days (2), Nearly every day (3). "
            "CRITICAL: Any response other than 'Not at all' (score > 0) triggers "
            "an immediate hardcoded crisis response. The LLM never handles this."
        ),
        category="phq9",
        metadata={"question": 9, "construct": "self_harm_ideation",
                  "safety_critical": True},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 Scoring: Total score 1-4 = Minimal depression. "
            "5-9 = Mild depression. 10-14 = Moderate depression. "
            "15-19 = Moderately severe depression. 20-27 = Severe depression. "
            "PHQ-9 score of 10 or higher on two consecutive screenings triggers "
            "the doctor directory alongside the exercises module."
        ),
        category="phq9",
        metadata={"type": "scoring"},
    ),
]

# ── DASS-21 Stress Subscale ───────────────────────────────────────────────────
# LEARN: DASS-21 has 3 subscales — Depression, Anxiety, Stress (7 items each)
# We use the Stress subscale primarily for the ML classifier
# Each item scored 0-3, multiply total by 2 to get DASS-42 equivalent
# Stress thresholds (DASS-42 equivalent): 15=mild, 19=moderate, 26=severe

DASS_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "DASS-21 Stress Subscale Introduction: Measures stress severity over the past week. "
            "Scored: Did not apply to me at all=0, Applied to me to some degree=1, "
            "Applied to me to a considerable degree=2, Applied to me very much=3. "
            "Multiply subscale total by 2 for DASS-42 equivalent score."
        ),
        category="dass",
        metadata={"type": "intro", "subscale": "stress"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Stress Item 1 (Item 1): I found it hard to wind down. "
            "Reflects difficulty relaxing and unwinding — a core stress indicator."
        ),
        category="dass",
        metadata={"item": 1, "subscale": "stress"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Stress Item 6 (Item 6): I tended to over-react to situations. "
            "Reflects emotional reactivity under stress."
        ),
        category="dass",
        metadata={"item": 6, "subscale": "stress"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Stress Item 8 (Item 8): I felt that I was using a lot of nervous energy. "
            "Reflects tension and nervous exhaustion."
        ),
        category="dass",
        metadata={"item": 8, "subscale": "stress"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Stress Item 11 (Item 11): I found myself getting agitated. "
            "Reflects irritability and agitation from stress."
        ),
        category="dass",
        metadata={"item": 11, "subscale": "stress"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Stress Item 12 (Item 12): I found it difficult to relax. "
            "Distinct from Item 1 — measures sustained inability to relax."
        ),
        category="dass",
        metadata={"item": 12, "subscale": "stress"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Stress Item 14 (Item 14): I was intolerant of anything that "
            "kept me from getting on with what I was doing. "
            "Reflects low frustration tolerance."
        ),
        category="dass",
        metadata={"item": 14, "subscale": "stress"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Stress Item 18 (Item 18): I felt that I was rather touchy. "
            "Reflects heightened sensitivity and irritability."
        ),
        category="dass",
        metadata={"item": 18, "subscale": "stress"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Stress Scoring (DASS-42 equivalent after x2): "
            "0-14 = Normal. 15-18 = Mild stress. 19-25 = Moderate stress. "
            "26-33 = Severe stress. 34+ = Extremely severe stress."
        ),
        category="dass",
        metadata={"type": "scoring", "subscale": "stress"},
    ),
]

# ── DSM-5 Criteria Summaries ──────────────────────────────────────────────────
# LEARN: These are simplified summaries of DSM-5 diagnostic criteria.
# The chatbot uses these to understand what signals map to what conditions.
# We never use these to "diagnose" — only to understand symptom patterns.

DSM5_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "DSM-5 Generalized Anxiety Disorder (GAD) criteria summary: "
            "Excessive anxiety and worry about multiple topics, more days than not, "
            "for at least 6 months. Difficulty controlling worry. "
            "3+ symptoms: restlessness, fatigue, concentration difficulty, "
            "irritability, muscle tension, sleep disturbance. "
            "Causes significant distress or functional impairment."
        ),
        category="dsm5",
        metadata={"condition": "GAD"},
    ),
    KnowledgeChunk(
        content=(
            "DSM-5 Major Depressive Disorder (MDD) criteria summary: "
            "5+ symptoms during same 2-week period, representing a change from baseline. "
            "Must include depressed mood OR loss of interest/pleasure (anhedonia). "
            "Other symptoms: weight/appetite change, insomnia/hypersomnia, "
            "psychomotor agitation/retardation, fatigue, worthlessness/guilt, "
            "concentration difficulty, recurrent thoughts of death or suicide. "
            "Causes significant distress or functional impairment."
        ),
        category="dsm5",
        metadata={"condition": "MDD"},
    ),
    KnowledgeChunk(
        content=(
            "DSM-5 ADHD criteria summary: "
            "Inattentive presentation: 6+ inattention symptoms (fails to finish tasks, "
            "difficulty sustaining attention, doesn't listen, loses things, forgetful, "
            "avoids sustained mental effort, easily distracted). "
            "Hyperactive/Impulsive: 6+ symptoms (fidgets, leaves seat, runs/climbs "
            "inappropriately, can't play quietly, talks excessively, blurts answers, "
            "can't wait turn, interrupts). "
            "CRITICAL DSM-5 requirement: symptoms present before age 12 (childhood onset). "
            "Present in 2+ settings. Causes functional impairment."
        ),
        category="dsm5",
        metadata={"condition": "ADHD"},
    ),
]

# ── DASS-21 Depression Subscale ──────────────────────────────────────────────
# Items: 3, 5, 10, 13, 16, 17, 21
# Thresholds (DASS-42 equivalent after x2): 10=mild, 14=moderate, 21=severe

DASS_DEPRESSION_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "DASS-21 Depression Subscale Introduction: Measures depression severity "
            "over the past week. Same 0-3 scoring as stress subscale. "
            "Multiply subscale total by 2 for DASS-42 equivalent."
        ),
        category="dass",
        metadata={"type": "intro", "subscale": "depression"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Depression Item 3: I couldn't seem to experience any positive feeling at all. "
            "Reflects anhedonia and emotional blunting — core depression signal."
        ),
        category="dass",
        metadata={"item": 3, "subscale": "depression", "construct": "anhedonia"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Depression Item 5: I found it difficult to work up the initiative "
            "to do things. Reflects anergia and motivational deficit."
        ),
        category="dass",
        metadata={"item": 5, "subscale": "depression", "construct": "anergia"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Depression Item 10: I felt that I had nothing to look forward to. "
            "Reflects hopelessness — a key depression and suicide risk indicator."
        ),
        category="dass",
        metadata={"item": 10, "subscale": "depression", "construct": "hopelessness"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Depression Item 13: I felt sad and depressed. "
            "Direct low mood — the core affective symptom of depression."
        ),
        category="dass",
        metadata={"item": 13, "subscale": "depression", "construct": "depressed_mood"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Depression Item 16: I was unable to become enthusiastic about anything. "
            "Reflects loss of interest and engagement across domains."
        ),
        category="dass",
        metadata={"item": 16, "subscale": "depression", "construct": "loss_of_interest"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Depression Item 17: I felt I wasn't worth much as a person. "
            "Reflects low self-worth and worthlessness — maps to PHQ-9 Q6."
        ),
        category="dass",
        metadata={"item": 17, "subscale": "depression", "construct": "worthlessness"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Depression Item 21: I felt that life wasn't worthwhile. "
            "Reflects nihilism and passive suicidal ideation — monitor carefully."
        ),
        category="dass",
        metadata={"item": 21, "subscale": "depression",
                  "construct": "life_worthwhile", "safety_monitor": True},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Depression Scoring (DASS-42 equivalent after x2): "
            "0-9 = Normal. 10-13 = Mild depression. 14-20 = Moderate depression. "
            "21-27 = Severe depression. 28+ = Extremely severe depression."
        ),
        category="dass",
        metadata={"type": "scoring", "subscale": "depression"},
    ),
]

# ── DASS-21 Anxiety Subscale ──────────────────────────────────────────────────
# Items: 2, 4, 7, 9, 15, 19, 20
# Thresholds (DASS-42 equivalent after x2): 8=mild, 10=moderate, 15=severe

DASS_ANXIETY_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "DASS-21 Anxiety Subscale Introduction: Measures anxiety and autonomic "
            "arousal over the past week. Captures physical anxiety symptoms "
            "that GAD-7 partially misses."
        ),
        category="dass",
        metadata={"type": "intro", "subscale": "anxiety"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Anxiety Item 2: I was aware of dryness of my mouth. "
            "Physical autonomic arousal — dry mouth is a classic anxiety symptom."
        ),
        category="dass",
        metadata={"item": 2, "subscale": "anxiety", "construct": "autonomic_arousal"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Anxiety Item 4: I experienced breathing difficulty. "
            "Shortness of breath or feeling unable to breathe deeply — "
            "common in panic and anxiety states."
        ),
        category="dass",
        metadata={"item": 4, "subscale": "anxiety", "construct": "breathing"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Anxiety Item 7: I experienced trembling (e.g. in the hands). "
            "Physical tremor — reflects high sympathetic nervous system activation."
        ),
        category="dass",
        metadata={"item": 7, "subscale": "anxiety", "construct": "tremor"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Anxiety Item 9: I was worried about situations in which I might "
            "panic and make a fool of myself. Reflects anticipatory anxiety — "
            "fear of having anxiety in public."
        ),
        category="dass",
        metadata={"item": 9, "subscale": "anxiety", "construct": "anticipatory_anxiety"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Anxiety Item 15: I felt I was close to panic. "
            "Direct panic proximity — high specificity for anxiety disorders."
        ),
        category="dass",
        metadata={"item": 15, "subscale": "anxiety", "construct": "panic"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Anxiety Item 19: I was aware of the action of my heart in the "
            "absence of physical exertion (e.g. sense of heart rate increase, "
            "heart missing a beat). Palpitations — classic somatic anxiety symptom."
        ),
        category="dass",
        metadata={"item": 19, "subscale": "anxiety", "construct": "palpitations"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Anxiety Item 20: I felt scared without any good reason. "
            "Free-floating fear without identifiable trigger — distinguishes "
            "anxiety disorders from normal situational fear."
        ),
        category="dass",
        metadata={"item": 20, "subscale": "anxiety", "construct": "free_floating_fear"},
    ),
    KnowledgeChunk(
        content=(
            "DASS-21 Anxiety Scoring (DASS-42 equivalent after x2): "
            "0-7 = Normal. 8-9 = Mild anxiety. 10-14 = Moderate anxiety. "
            "15-19 = Severe anxiety. 20+ = Extremely severe anxiety."
        ),
        category="dass",
        metadata={"type": "scoring", "subscale": "anxiety"},
    ),
]

# ── ASRS v1.1 (Adult ADHD Self-Report Scale) ─────────────────────────────────
# LEARN: ASRS has 18 questions total. Part A (6 questions) is most predictive.
# Scoring: Never=0, Rarely=1, Sometimes=2, Often=3, Very Often=4
# Part A threshold: 4+ questions scored Sometimes/Often/Very Often = significant
# Childhood onset (before age 12) is a DSM-5 REQUIREMENT for ADHD diagnosis

ASRS_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "ASRS v1.1 Introduction: The Adult ADHD Self-Report Scale screens for "
            "ADHD symptoms in adults. Part A (6 questions) is the most predictive. "
            "Scoring: Never=0, Rarely=1, Sometimes=2, Often=3, Very Often=4. "
            "Part A: 4+ questions at Sometimes or higher = clinically significant. "
            "CRITICAL: Childhood onset (symptoms before age 12) is required by DSM-5."
        ),
        category="asrs",
        metadata={"type": "intro", "parts": ["A", "B"],
                  "threshold": "4+ on Part A"},
    ),
    KnowledgeChunk(
        content=(
            "ASRS Part A Question 1: How often do you have trouble wrapping up the "
            "final details of a project, once the challenging parts have been done? "
            "Scored: Never(0) Rarely(1) Sometimes(2) Often(3) Very Often(4). "
            "Threshold: Sometimes or higher counts toward Part A score."
        ),
        category="asrs",
        metadata={"question": 1, "part": "A", "construct": "task_completion"},
    ),
    KnowledgeChunk(
        content=(
            "ASRS Part A Question 2: How often do you have difficulty getting things "
            "in order when you have to do a task that requires organization? "
            "Scored: Never(0) Rarely(1) Sometimes(2) Often(3) Very Often(4). "
            "Threshold: Sometimes or higher counts toward Part A score."
        ),
        category="asrs",
        metadata={"question": 2, "part": "A", "construct": "organization"},
    ),
    KnowledgeChunk(
        content=(
            "ASRS Part A Question 3: How often do you have problems remembering "
            "appointments or obligations? "
            "Scored: Never(0) Rarely(1) Sometimes(2) Often(3) Very Often(4). "
            "Threshold: Sometimes or higher counts toward Part A score."
        ),
        category="asrs",
        metadata={"question": 3, "part": "A", "construct": "forgetfulness"},
    ),
    KnowledgeChunk(
        content=(
            "ASRS Part A Question 4: When you have a task that requires a lot of "
            "thought, how often do you avoid or delay getting started? "
            "Scored: Never(0) Rarely(1) Sometimes(2) Often(3) Very Often(4). "
            "Threshold: Sometimes or higher counts toward Part A score. "
            "Maps to DSM-5 avoidance of sustained mental effort criterion."
        ),
        category="asrs",
        metadata={"question": 4, "part": "A", "construct": "task_avoidance"},
    ),
    KnowledgeChunk(
        content=(
            "ASRS Part A Question 5: How often do you fidget or squirm with your "
            "hands or feet when you have to sit down for a long time? "
            "Scored: Never(0) Rarely(1) Sometimes(2) Often(3) Very Often(4). "
            "Threshold: Often or Very Often counts (higher bar for this item)."
        ),
        category="asrs",
        metadata={"question": 5, "part": "A", "construct": "hyperactivity_motor"},
    ),
    KnowledgeChunk(
        content=(
            "ASRS Part A Question 6: How often do you feel overly active and "
            "compelled to do things, like you were driven by a motor? "
            "Scored: Never(0) Rarely(1) Sometimes(2) Often(3) Very Often(4). "
            "Threshold: Often or Very Often counts (higher bar for this item)."
        ),
        category="asrs",
        metadata={"question": 6, "part": "A", "construct": "hyperactivity_driven"},
    ),
    KnowledgeChunk(
        content=(
            "ASRS Part A Scoring: Count the number of questions where the response "
            "is Sometimes, Often, or Very Often (for Q1-Q4) or Often/Very Often "
            "(for Q5-Q6). If 4 or more questions meet threshold: "
            "highly consistent with ADHD symptoms. "
            "IMPORTANT: ASRS alone cannot diagnose ADHD. "
            "Professional evaluation is required for formal diagnosis."
        ),
        category="asrs",
        metadata={"type": "scoring", "part": "A"},
    ),
]

# ── Clinical descriptions (symptom-to-condition mapping) ─────────────────────
# LEARN: These chunks bridge the gap between user language and clinical language.
# A user won't say "I have anhedonia" — they say "nothing feels worth doing."
# When that user message gets embedded and searched, these chunks should surface
# and tell the LLM: this maps to PHQ-9 Q1.

GAD_DESCRIPTION_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "Generalized anxiety often feels like a constant background hum of worry "
            "that doesn't switch off, even when things are objectively fine. "
            "People describe it as 'waiting for something bad to happen' or feeling "
            "unable to relax even during downtime."
        ),
        category="gad7_context",
        metadata={"maps_to": "GAD-7 general"},
    ),
    KnowledgeChunk(
        content=(
            "The difference between normal worry and GAD-level anxiety is control "
            "and interference. Normal worry passes once the situation resolves. "
            "GAD-level worry persists across unrelated situations and interferes "
            "with sleep, focus, or daily tasks."
        ),
        category="gad7_context",
        metadata={"maps_to": "GAD-7 Q1, Q2"},
    ),
    KnowledgeChunk(
        content=(
            "Physical anxiety symptoms — racing heart, tight chest, restlessness, "
            "muscle tension — often get described by users as 'I feel on edge' or "
            "'my body won't calm down,' without them naming it as anxiety."
        ),
        category="gad7_context",
        metadata={"maps_to": "GAD-7 Q5, Q6"},
    ),
]

DEPRESSION_DESCRIPTION_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "Anhedonia — loss of interest or pleasure — usually shows up in user "
            "language as 'nothing feels worth doing anymore' or 'I don't enjoy "
            "things I used to.' This is PHQ-9 Q1 and one of the two core "
            "depression symptoms required for MDD diagnosis."
        ),
        category="phq9_context",
        metadata={"maps_to": "PHQ-9 Q1"},
    ),
    KnowledgeChunk(
        content=(
            "Low mood in depression is often described as 'flat,' 'numb,' or "
            "'going through the motions' rather than sadness directly. "
            "Users may say 'I just feel empty' or 'I don't feel anything.' "
            "This maps to PHQ-9 Q2 — depressed mood."
        ),
        category="phq9_context",
        metadata={"maps_to": "PHQ-9 Q2"},
    ),
    KnowledgeChunk(
        content=(
            "Fatigue in depression is different from normal tiredness — it doesn't "
            "improve with rest and is often paired with low motivation, described as "
            "'even small tasks feel exhausting' or 'I have no energy for anything.' "
            "This maps to PHQ-9 Q4."
        ),
        category="phq9_context",
        metadata={"maps_to": "PHQ-9 Q4"},
    ),
]

ADHD_DESCRIPTION_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "Adult ADHD inattention often shows up as 'I start things but never "
            "finish them,' losing track of tasks mid-way, or chronic difficulty "
            "with follow-through despite good intentions. "
            "Maps to ASRS Part A Q1 and Q4."
        ),
        category="asrs_context",
        metadata={"maps_to": "ASRS Part A Q1, Q4"},
    ),
    KnowledgeChunk(
        content=(
            "Disorganization in ADHD is described less as laziness and more as "
            "'I know what I need to do but can't figure out the order' or losing "
            "things constantly despite trying to stay organized. "
            "Maps to ASRS Part A Q2 and Q3."
        ),
        category="asrs_context",
        metadata={"maps_to": "ASRS Part A Q2, Q3"},
    ),
    KnowledgeChunk(
        content=(
            "Childhood onset is a hard DSM-5 requirement for ADHD. "
            "When a user says 'I've been like this my whole life' or 'school was "
            "a nightmare for me,' that confirms childhood onset and is critical "
            "for the ADHD diagnosis pathway. Always confirm this explicitly."
        ),
        category="asrs_context",
        metadata={"maps_to": "DSM-5 ADHD criteria C — childhood onset"},
    ),
]

# ── Differential context ──────────────────────────────────────────────────────
# LEARN: These help the chatbot distinguish between conditions that
# present similarly. Burnout vs depression is the most common confusion.

DIFFERENTIAL_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "Burnout is typically tied to a specific context — usually work or "
            "caregiving — and tends to improve with rest, boundaries, or a change "
            "in workload. Depression persists across all contexts and doesn't "
            "lift with rest alone."
        ),
        category="differential_context",
        metadata={"maps_to": "burnout_vs_mdd"},
    ),
    KnowledgeChunk(
        content=(
            "Burnout usually preserves interest in things outside the draining "
            "context — hobbies, relationships, leisure. Depression tends to flatten "
            "interest across the board. If the user says 'I love my weekends but "
            "hate work,' that points toward burnout, not MDD."
        ),
        category="differential_context",
        metadata={"maps_to": "burnout_vs_mdd"},
    ),
    KnowledgeChunk(
        content=(
            "Anxiety and depression frequently co-occur (comorbidity). "
            "A user describing both persistent worry AND low mood / loss of "
            "interest should be routed to both GAD-7 and PHQ-9. "
            "Don't assume it's one or the other."
        ),
        category="differential_context",
        metadata={"maps_to": "anxiety_depression_comorbidity"},
    ),
    KnowledgeChunk(
        content=(
            "ADHD and anxiety can look similar on the surface — both involve "
            "restlessness, difficulty concentrating, and sleep problems. "
            "Key differentiator: ADHD symptoms are pervasive since childhood "
            "across all settings. Anxiety is often situational or developed "
            "in response to life stressors."
        ),
        category="differential_context",
        metadata={"maps_to": "adhd_vs_anxiety"},
    ),
]

# ── Scoring interpretations ───────────────────────────────────────────────────
# LEARN: These are shown to the user after questionnaire completion.
# They never say "you have X" — only "your score is consistent with X level."
# The framing rule is enforced everywhere.

GAD7_INTERPRETATION_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "GAD-7 score 0-4: Minimal anxiety. "
            "Your responses suggest minimal anxiety symptoms at this time. "
            "No clinical action typically needed."
        ),
        category="gad7_scoring",
        metadata={"range": "0-4", "label": "minimal"},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 score 5-9: Mild anxiety. "
            "Your responses are consistent with mild anxiety. "
            "Self-monitoring and stress-reduction strategies may help."
        ),
        category="gad7_scoring",
        metadata={"range": "5-9", "label": "mild"},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 score 10-14: Moderate anxiety. "
            "Your responses are consistent with moderate anxiety. "
            "Consider discussing with a healthcare provider if symptoms persist."
        ),
        category="gad7_scoring",
        metadata={"range": "10-14", "label": "moderate"},
    ),
    KnowledgeChunk(
        content=(
            "GAD-7 score 15-21: Severe anxiety. "
            "Your responses are consistent with severe anxiety symptoms. "
            "Professional evaluation is recommended."
        ),
        category="gad7_scoring",
        metadata={"range": "15-21", "label": "severe"},
    ),
]

PHQ9_INTERPRETATION_CHUNKS: list[KnowledgeChunk] = [
    KnowledgeChunk(
        content=(
            "PHQ-9 score 0-4: Minimal depression symptoms. "
            "No clinical action typically needed."
        ),
        category="phq9_scoring",
        metadata={"range": "0-4", "label": "minimal"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 score 5-9: Mild depression symptoms. "
            "Monitoring is reasonable. Consider lifestyle factors — "
            "sleep, exercise, social connection."
        ),
        category="phq9_scoring",
        metadata={"range": "5-9", "label": "mild"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 score 10-14: Moderate depression. "
            "Your responses are consistent with moderate depression symptoms. "
            "Professional consultation is recommended."
        ),
        category="phq9_scoring",
        metadata={"range": "10-14", "label": "moderate"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 score 15-19: Moderately severe depression. "
            "Your responses are consistent with moderately severe depression. "
            "Professional evaluation is strongly recommended."
        ),
        category="phq9_scoring",
        metadata={"range": "15-19", "label": "moderately_severe"},
    ),
    KnowledgeChunk(
        content=(
            "PHQ-9 score 20-27: Severe depression. "
            "Your responses are consistent with severe depression symptoms. "
            "Prompt professional evaluation is strongly recommended."
        ),
        category="phq9_scoring",
        metadata={"range": "20-27", "label": "severe"},
    ),
]

# ── All chunks combined ───────────────────────────────────────────────────────
# LEARN: This is the complete knowledge base.
# Every chunk here gets embedded and stored in pgvector at startup.
# Total chunks: ~80 — small enough to fit in memory, large enough to be useful.

ALL_CHUNKS: list[KnowledgeChunk] = (
    GAD7_CHUNKS
    + PHQ9_CHUNKS
    + DASS_CHUNKS
    + DASS_DEPRESSION_CHUNKS
    + DASS_ANXIETY_CHUNKS
    + ASRS_CHUNKS
    + DSM5_CHUNKS
    + GAD_DESCRIPTION_CHUNKS
    + DEPRESSION_DESCRIPTION_CHUNKS
    + ADHD_DESCRIPTION_CHUNKS
    + DIFFERENTIAL_CHUNKS
    + GAD7_INTERPRETATION_CHUNKS
    + PHQ9_INTERPRETATION_CHUNKS
)
