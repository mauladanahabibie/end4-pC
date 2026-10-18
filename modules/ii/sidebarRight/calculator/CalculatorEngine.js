/**
 * CalculatorEngine.js
 * Safe Mathematical Expression Evaluator using Dijkstra's Shunting-Yard Algorithm
 * and Reverse Polish Notation (RPN) evaluation.
 *
 * NO eval(), NO Function(), NO shell execution.
 */

.pragma library

function tokenize(input) {
    if (!input || typeof input !== "string") return [];
    
    // Normalize display symbols: × -> *, ÷ -> /
    let str = input.replace(/×/g, "*").replace(/÷/g, "/").trim();
    
    const tokens = [];
    let i = 0;
    const len = str.length;

    while (i < len) {
        const ch = str[i];

        // Skip whitespace
        if (/\s/.test(ch)) {
            i++;
            continue;
        }

        // Numbers (digits and decimal point)
        if (/[0-9]/.test(ch) || (ch === '.' && i + 1 < len && /[0-9]/.test(str[i + 1]))) {
            let numStr = "";
            let hasDot = false;
            while (i < len && (/[0-9]/.test(str[i]) || str[i] === '.')) {
                if (str[i] === '.') {
                    if (hasDot) break;
                    hasDot = true;
                }
                numStr += str[i];
                i++;
            }
            tokens.push({ type: "NUMBER", value: parseFloat(numStr) });
            continue;
        }

        // Parentheses
        if (ch === '(') {
            tokens.push({ type: "LPAREN", value: "(" });
            i++;
            continue;
        }
        if (ch === ')') {
            tokens.push({ type: "RPAREN", value: ")" });
            i++;
            continue;
        }

        // Percentage operator (postfix)
        if (ch === '%') {
            tokens.push({ type: "PERCENT", value: "%" });
            i++;
            continue;
        }

        // Unary minus or binary minus
        if (ch === '-') {
            const prevToken = tokens.length > 0 ? tokens[tokens.length - 1] : null;
            const isUnary = !prevToken || prevToken.type === "OPERATOR" || prevToken.type === "LPAREN";
            if (isUnary) {
                // If followed immediately by a number, parse negative number
                let nextIdx = i + 1;
                while (nextIdx < len && /\s/.test(str[nextIdx])) nextIdx++;
                if (nextIdx < len && (/[0-9]/.test(str[nextIdx]) || str[nextIdx] === '.')) {
                    i = nextIdx;
                    let numStr = "-";
                    let hasDot = false;
                    while (i < len && (/[0-9]/.test(str[i]) || str[i] === '.')) {
                        if (str[i] === '.') {
                            if (hasDot) break;
                            hasDot = true;
                        }
                        numStr += str[i];
                        i++;
                    }
                    tokens.push({ type: "NUMBER", value: parseFloat(numStr) });
                    continue;
                } else {
                    // Unary minus before parenthesis: convert to "0 -"
                    tokens.push({ type: "NUMBER", value: 0 });
                    tokens.push({ type: "OPERATOR", value: "-", precedence: 1, assoc: "L" });
                    i++;
                    continue;
                }
            } else {
                tokens.push({ type: "OPERATOR", value: "-", precedence: 1, assoc: "L" });
                i++;
                continue;
            }
        }

        // Binary operators
        if (ch === '+') {
            tokens.push({ type: "OPERATOR", value: "+", precedence: 1, assoc: "L" });
            i++;
            continue;
        }
        if (ch === '*') {
            tokens.push({ type: "OPERATOR", value: "*", precedence: 2, assoc: "L" });
            i++;
            continue;
        }
        if (ch === '/') {
            tokens.push({ type: "OPERATOR", value: "/", precedence: 2, assoc: "L" });
            i++;
            continue;
        }

        // Unknown character
        return { error: "Unexpected character: " + ch };
    }

    return tokens;
}

function toRPN(tokens) {
    const outputQueue = [];
    const operatorStack = [];

    for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i];

        if (token.type === "NUMBER") {
            outputQueue.push(token);
        } else if (token.type === "PERCENT") {
            outputQueue.push(token);
        } else if (token.type === "OPERATOR") {
            while (operatorStack.length > 0) {
                const top = operatorStack[operatorStack.length - 1];
                if (top.type === "OPERATOR" &&
                    ((token.assoc === "L" && token.precedence <= top.precedence) ||
                     (token.assoc === "R" && token.precedence < top.precedence))) {
                    outputQueue.push(operatorStack.pop());
                } else {
                    break;
                }
            }
            operatorStack.push(token);
        } else if (token.type === "LPAREN") {
            operatorStack.push(token);
        } else if (token.type === "RPAREN") {
            let foundLparen = false;
            while (operatorStack.length > 0) {
                const top = operatorStack.pop();
                if (top.type === "LPAREN") {
                    foundLparen = true;
                    break;
                }
                outputQueue.push(top);
            }
            if (!foundLparen) {
                return { error: "Mismatched parentheses" };
            }
        }
    }

    while (operatorStack.length > 0) {
        const top = operatorStack.pop();
        if (top.type === "LPAREN" || top.type === "RPAREN") {
            return { error: "Mismatched parentheses" };
        }
        outputQueue.push(top);
    }

    return outputQueue;
}

function evaluateRPN(rpnTokens) {
    const stack = [];

    for (let i = 0; i < rpnTokens.length; i++) {
        const token = rpnTokens[i];

        if (token.type === "NUMBER") {
            stack.push(token.value);
        } else if (token.type === "PERCENT") {
            if (stack.length === 0) return { error: "Invalid expression" };
            const val = stack.pop();
            stack.push(val / 100);
        } else if (token.type === "OPERATOR") {
            if (stack.length < 2) {
                return { error: "Invalid expression" };
            }
            const b = stack.pop();
            const a = stack.pop();

            switch (token.value) {
                case "+":
                    stack.push(a + b);
                    break;
                case "-":
                    stack.push(a - b);
                    break;
                case "*":
                    stack.push(a * b);
                    break;
                case "/":
                    if (Math.abs(b) < 1e-15) {
                        return { error: "Cannot divide by zero" };
                    }
                    stack.push(a / b);
                    break;
                default:
                    return { error: "Unknown operator: " + token.value };
            }
        }
    }

    if (stack.length !== 1) {
        return { error: "Invalid expression" };
    }

    const rawResult = stack[0];
    if (isNaN(rawResult) || !isFinite(rawResult)) {
        return { error: "Invalid calculation result" };
    }

    // Clean floating point artifacts (e.g. 0.1 + 0.2 = 0.3)
    const cleaned = parseFloat(rawResult.toPrecision(12));
    return { success: true, result: cleaned };
}

function evaluate(expression) {
    if (!expression || typeof expression !== "string" || expression.trim().length === 0) {
        return { success: false, error: "Empty expression" };
    }

    const tokens = tokenize(expression);
    if (tokens.error) {
        return { success: false, error: tokens.error };
    }
    if (tokens.length === 0) {
        return { success: false, error: "Empty expression" };
    }

    const rpn = toRPN(tokens);
    if (rpn.error) {
        return { success: false, error: rpn.error };
    }

    const evalResult = evaluateRPN(rpn);
    if (evalResult.error) {
        return { success: false, error: evalResult.error };
    }

    return evalResult;
}
