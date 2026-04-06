# 📝 Coding Conventions & Styles

*This file defines the "Muscle Memory" for AI agents. Adhere to these styles strictly.*

## 1. Naming Conventions
- **Variables/Functions:** `camelCase`
- **Classes/Types:** `PascalCase`
- **Files:** `kebab-case`
- **Constants:** `UPPER_SNAKE_CASE`

## 2. Prohibited Patterns (Anti-Patterns)
- ❌ No `console.log` in production code (use a logger).
- ❌ No hardcoded secrets or sensitive configs (use environment variables).
- ❌ No logic-heavy constructors.

## 3. Error Handling
- Use structured error responses.
- Always handle edge cases and null/undefined checks.

## 4. Documentation
- Use JSDoc/Docstrings for all exported functions and classes.
- Keep comments meaningful (Why, not What).
