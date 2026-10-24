# 3. AI Adoption and Implementation Procedure

**Company:** [Company Name] | **Owner:** [Name, role] | **Version:** 1.3 | **Effective:** [date]

## Objective
This procedure outlines how the business adopts AI in a controlled and secure manner and how it implements the minimum governance required for operational use. It applies to Microsoft 365 Copilot, GitHub Copilot, approved model services, AI-enabled SaaS tools and internal or vendor-developed AI agents.

The organisation must treat AI adoption as a governed change activity rather than a free-form technology rollout.

## Phase 1: Governance foundations before use

### Step 1. Assign accountability
- assign an AI owner
- assign an executive sponsor
- confirm who approves new AI tools, models and agents
- identify who owns AI security, data handling and incident response

### Step 2. Define business and security boundaries
- define the approved AI tool list
- document the data classes: General, Restricted and Never
- record approved use cases and prohibited use cases
- define whether AI agents are permitted and under what conditions

### Step 3. Implement baseline controls
Before user access is granted, the business must ensure:

- MFA or passkeys are enabled for AI user and admin accounts
- least-privilege access is applied
- broad file sharing is reviewed and reduced where necessary
- logging and audit controls are enabled
- approval and exception processes are documented
- incident reporting and escalation steps are communicated

### Step 4. Maintain the AI inventory
Create and maintain a register of:

- approved AI tools and services
- AI usage by user group or team
- AI agents and workflows
- connectors, integrations and model access
- owners and business purpose

## Phase 2: Pilot implementation
Use a limited pilot before broader rollout. Typical pilot scope:

- 5 to 10 users, or a single function or team
- low-risk use cases only
- approved data classes only
- human review required for all outputs that are published, sent or acted on

Recommended pilot use cases:

- meeting summarisation
- drafting internal documents
- research and summarisation
- coding assistance for approved developers
- knowledge retrieval within approved systems

Pilot controls:

- restrict access to approved users only
- prohibit Restricted or Never data in prompts
- review AI outputs for quality, privacy and security issues
- collect feedback on hallucination risk and usefulness
- sample logs and review for oversharing or suspicious behaviour

## Phase 3: Security verification before broader rollout
Before expanding beyond the pilot, validate the following:

- AI policy is in place and acknowledged by users
- no prohibited data is being entered into AI tools
- MFA and identity controls are enforced
- prompts and agent actions are logged
- permissions are least privilege
- prompt injection and malicious input tests are complete where agents are used
- user training is complete
- an incident reporting path exists and has been tested

## Phase 4: Expand in controlled waves
Roll out in waves rather than all at once. Expansion should occur only after the pilot review and with evidence that the controls remain effective.

### Wave 1: productivity enablement
- Microsoft 365 Copilot for approved functions
- GitHub Copilot for approved engineering use
- only General and approved Restricted data in approved scenarios

### Wave 2: broader team rollout
- expand by function or department
- continue monthly review of output quality and risk
- review DLP prompts, connector use and app consent activity

### Wave 3: approved AI agents
Introduce AI agents only after the organisation has validated:

- named owner and defined purpose
- dedicated identity and access scope
- logging of actions and prompts
- kill switch and rollback path
- prompt injection testing and approval controls

Agents should start with read-only or assistive actions, not autonomous business operations.

## AI agent implementation requirements
For any internal or vendor-built AI agent, the following must be completed before production use:

- business use case is approved
- owner is assigned and accountable
- data access is mapped and justified
- connector list is reviewed and allow-listed
- secret management is reviewed
- human approval is required for irreversible actions
- prompt-injection testing is complete
- external system access is restricted to approved boundaries
- log retention and alerting are enabled

## Approval thresholds
The following require written approval before use:

- new AI tool or vendor
- AI systems handling customer or employee data
- AI agents with external actions or connector access
- custom model integrations or API use
- any workflow involving financial, HR, legal, health or regulated information

## Exit criteria for broader rollout
The business may expand AI use only when:

- policy is published and acknowledged
- AI owner and sponsor are assigned
- identity and access controls are in place
- tool list is approved
- user training is complete
- pilot review is complete
- incident response process is in place
- any AI agent is registered and reviewed

## Review cycle
This procedure should be reviewed:

- after the first pilot cycle
- after each major AI expansion
- at least every 6 months

**Approved by:** [Name] | [Role] | [Date]
