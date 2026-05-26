# Production Contract 

## What "contract" means here

In this context, a **contract** is an explicit set of expectations that must stay
true while refactoring:

- which files define the production workflow,
- what inputs they require,
- what outputs they produce,
- and what behaviors must not change without deliberate review.

This makes architecture changes safer by giving us a stable baseline to test against.

## Contract: execution flow



## Contract: model selection and settings


## Contract: outputs


## Change policy

Any change that alters this contract should be:

1. intentional,
2. documented,
3. reviewed with project-purpose rationale,
4. validated with a lightweight check before broader refactoring.
