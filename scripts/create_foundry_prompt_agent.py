"""Create and optionally smoke-test a Microsoft Foundry prompt agent."""

import argparse
import json
import os

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import PromptAgentDefinition
from azure.identity import DefaultAzureCredential


DEFAULT_INSTRUCTIONS = (
    "You are a helpful assistant accessed through OpenWebUI. "
    "Give clear, concise, and accurate answers."
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-endpoint",
        default=os.getenv("AZURE_AI_PROJECT_ENDPOINT"),
        help="Foundry project endpoint. Defaults to AZURE_AI_PROJECT_ENDPOINT.",
    )
    parser.add_argument(
        "--agent-name",
        default="openwebui-prompt-agent",
        help="Versioned Foundry agent name.",
    )
    parser.add_argument(
        "--model",
        default="gpt-5.4-mini",
        help="Foundry model deployment name.",
    )
    parser.add_argument(
        "--instructions",
        default=DEFAULT_INSTRUCTIONS,
        help="Prompt agent instructions.",
    )
    parser.add_argument(
        "--skip-smoke-test",
        action="store_true",
        help="Create the agent without invoking it.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.project_endpoint:
        raise SystemExit(
            "Set AZURE_AI_PROJECT_ENDPOINT or pass --project-endpoint before creating an agent."
        )

    with (
        DefaultAzureCredential() as credential,
        AIProjectClient(endpoint=args.project_endpoint, credential=credential) as project_client,
    ):
        agent = project_client.agents.create_version(
            agent_name=args.agent_name,
            definition=PromptAgentDefinition(
                model=args.model,
                instructions=args.instructions,
            ),
            description="Prompt agent created for OpenWebUI and LiteLLM integration experiments.",
        )

        result = {
            "agent_id": agent.id,
            "agent_name": agent.name,
            "agent_version": agent.version,
            "model": args.model,
        }

        if not args.skip_smoke_test:
            with project_client.get_openai_client() as openai_client:
                conversation = openai_client.conversations.create(
                    items=[
                        {
                            "type": "message",
                            "role": "user",
                            "content": "Reply with exactly: prompt agent ready",
                        }
                    ]
                )
                response = openai_client.responses.create(
                    conversation=conversation.id,
                    extra_body={
                        "agent_reference": {
                            "name": agent.name,
                            "type": "agent_reference",
                        }
                    },
                )
                result["smoke_test_output"] = response.output_text
                openai_client.conversations.delete(conversation_id=conversation.id)

        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
