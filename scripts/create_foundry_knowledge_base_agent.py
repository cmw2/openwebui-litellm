"""Create or update the Poppy Foundry IQ knowledge-base prompt agent."""

import argparse
import json
import os

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import MCPTool, PromptAgentDefinition
from azure.identity import DefaultAzureCredential


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-endpoint",
        default=os.getenv("AZURE_AI_PROJECT_ENDPOINT"),
        required=not os.getenv("AZURE_AI_PROJECT_ENDPOINT"),
    )
    parser.add_argument(
        "--search-endpoint",
        default=os.getenv("AZURE_SEARCH_ENDPOINT"),
        required=not os.getenv("AZURE_SEARCH_ENDPOINT"),
    )
    parser.add_argument(
        "--project-connection-id",
        default=os.getenv("FOUNDRY_KNOWLEDGE_BASE_CONNECTION_ID"),
        required=not os.getenv("FOUNDRY_KNOWLEDGE_BASE_CONNECTION_ID"),
    )
    parser.add_argument("--knowledge-base-name", default="poppy-sharepoint-kb")
    parser.add_argument("--agent-name", default="poppy-knowledge-base-agent")
    parser.add_argument("--model", default="gpt-5.4-mini")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    mcp_endpoint = (
        f"{args.search_endpoint.rstrip('/')}/knowledgebases/"
        f"{args.knowledge_base_name}/mcp?api-version=2026-08-01-preview"
    )
    instructions = """
Use the knowledge base to answer Poppy questions. Do not answer from general
knowledge. If the knowledge base does not contain the answer, say "I don't
know".

The knowledge_base_retrieve result contains one or more JSON documents. Each
document can contain a canonical SharePoint file URL in doc_url. For every
answer grounded in a retrieved document, end the response with a "Sources"
section.

Do not link directly to a SharePoint file URL because browsers can download
some file types. Instead, convert doc_url to a SharePoint document-library UI
link in this form:
https://<host><site-and-library>/Forms/AllItems.aspx?id=<server-relative-file-path>&parent=<server-relative-library-path>

For example, a doc_url of:
https://tenant.sharepoint.com/sites/hr/Shared%20Documents/handbook.md

becomes:
https://tenant.sharepoint.com/sites/hr/Shared%20Documents/Forms/AllItems.aspx?id=/sites/hr/Shared%20Documents/handbook.md&parent=/sites/hr/Shared%20Documents

Include one Markdown link per source using that document-library UI URL:
- [descriptive document title](SharePoint library UI URL)

Never use the knowledge-base MCP endpoint, a generic doc_N citation, or the
raw file URL as a source link. If a retrieved document has no doc_url, state
that its original source URL was unavailable rather than inventing a link.
""".strip()

    with AIProjectClient(
        endpoint=args.project_endpoint, credential=DefaultAzureCredential()
    ) as project:
        tool = MCPTool(
            server_label="knowledge-base",
            server_url=mcp_endpoint,
            require_approval="never",
            allowed_tools=["knowledge_base_retrieve"],
            project_connection_id=args.project_connection_id,
        )
        agent = project.agents.create_version(
            agent_name=args.agent_name,
            definition=PromptAgentDefinition(
                model=args.model,
                instructions=instructions,
                tools=[tool],
            ),
            description=(
                "Poppy Foundry IQ agent that returns canonical SharePoint links "
                "from knowledge-base MCP results."
            ),
        )

    print(
        json.dumps(
            {
                "agent_name": agent.name,
                "agent_version": agent.version,
                "mcp_endpoint": mcp_endpoint,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
