# Usage Guide

Real scenarios showing how to use codex-vault in daily work. Each scenario shows exactly what you type and what happens.

> Examples use Claude Code (`/skill`). Codex CLI users: replace `/skill` with `$skill`.

## Scenario 1: First Session After Install

You just ran `install.sh`. Open your agent:

```
you: (agent starts — session-start hook fires automatically)
agent: "You're working in project X. North Star is empty. No active work notes yet."
```

Fill in your goals:

```
you: /dump My current focus is building a recommendation engine. Short-term goal:
     get a prototype running with collaborative filtering by end of month.
agent: → Updated brain/North Star.md (Current Focus + Short-term goal)
       → Created work/active/Recommendation Engine.md
       → Updated work/Index.md
```

That's it. Next session, the agent starts with this context.

## Scenario 2: Capturing a Decision Mid-Work

You're coding and make an architecture choice:

```
you: /dump We decided to use Redis instead of Memcached for session caching
     because we need pub/sub for real-time invalidation.
agent: → Updated brain/Key Decisions.md
       → Created work/active/Redis Session Caching.md (or updated existing note)
       → Cross-linked to [[Recommendation Engine]] if relevant
```

Next week, when you (or a teammate) ask "why Redis?", the agent already knows.

## Scenario 3: Reading an Article and Saving Insights

You found a useful blog post:

```
you: /ingest https://example.com/scaling-collaborative-filtering
agent: (fetches content, saves to sources/)
       "Here are the top 5 takeaways:
        1. Item-based CF scales better than user-based at >1M users
        2. ALS outperforms SGD for implicit feedback
        3. ...
        Which points matter most for your work?"
you: 1 and 2 are directly relevant
agent: → Created work/active/Scaling Collaborative Filtering.md (source summary)
       → Cross-linked to [[Recommendation Engine]]
       → Updated brain/Patterns.md with scaling insight
```

## Scenario 4: Searching Your Memory

You vaguely remember a past decision but not the details:

```
you: /recall caching strategy
agent: Found in:
       - [[Redis Session Caching]] — decided Redis over Memcached for pub/sub
       - [[Scaling Collaborative Filtering]] — mentioned caching intermediate results
       Summary: You chose Redis for session caching (pub/sub need). The CF article
       also suggested caching similarity matrices...
```

## Scenario 5: Picking Up Where You Left Off

New session, new day:

```
you: (agent starts)
agent: "Working on Recommendation Engine. Last session you decided on Redis for
        session caching. Recent commits: added CF prototype scaffold. Open question:
        whether to use implicit or explicit feedback."
you: Let's go with implicit feedback — we have more click data than ratings
agent: (classify hook detects a decision)
       "Noted — want me to /dump this decision?"
you: /dump Using implicit feedback for CF — we have 10x more click events than
     explicit ratings. ALS as the solver per the scaling article.
agent: → Updated brain/Key Decisions.md
       → Updated [[Recommendation Engine]] with decision
       → Cross-linked to [[Scaling Collaborative Filtering]]
```

## Scenario 6: Wrapping Up a Session

Done for the day:

```
you: /wrap-up
agent: Review:
       - Done: captured implicit feedback decision, updated 3 notes
       - Fixed: added missing [[wikilink]] in Redis Session Caching
       - Flagged: Recommendation Engine.md has no tags — added "ml, prototype"
       - Suggested: brain/Patterns.md could use the "implicit > explicit" pattern
```

## Scenario 7: Completing a Project

The prototype ships:

```
you: /dump Recommendation engine v1 shipped. Implicit CF with ALS, Redis caching,
     handles 500K users. Moving on to A/B testing framework.
agent: → Moved work/active/Recommendation Engine.md → work/archive/
       → Updated work/Index.md (active → completed)
       → Created work/active/AB Testing Framework.md
       → Updated brain/North Star.md (new focus)
```

## Daily Workflow Summary

| When | What | Skill |
|------|------|-------|
| Session starts | Agent loads context automatically | (hook) |
| You make a decision | Capture it | `/dump` |
| You read something useful | Save insights | `/ingest` |
| You need past context | Search memory | `/recall` |
| Session ends | Clean up and verify | `/wrap-up` |

## Tips

- **You don't need to use every skill every session.** Most sessions are just coding with an occasional `/dump`.
- **The classify hook suggests skills** — you decide whether to run them. The agent never auto-writes vault notes.
- **Write goals first.** `brain/North Star.md` is the most impactful file. A good North Star makes every session start useful.
- **Don't over-organize.** The vault is a tool, not a chore. Capture decisions and insights; skip routine updates.
- **Use Obsidian for browsing.** Open the vault folder in Obsidian to see the graph view and backlinks — great for discovering connections you missed.
