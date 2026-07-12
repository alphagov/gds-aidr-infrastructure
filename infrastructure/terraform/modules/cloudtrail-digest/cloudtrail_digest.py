"""
cloudtrail_digest.py

Queries CloudTrail for the past 7 days of team role activity across
a single AWS account and publishes a formatted summary to SNS.

Triggered weekly by EventBridge. One Lambda instance runs per account
(Development, Staging, Production), each publishing to the same SNS
topic in Production.

Environment variables (set by Terraform):
    SNS_TOPIC_ARN   — the SNS topic to publish the digest to
    ACCOUNT_LABEL   — human-readable account name (e.g. "Development")
    ROLE_PREFIX     — the IAM role prefix to filter on (e.g. "gds-aidr")
"""

import os
import json
import boto3
from datetime import datetime, timedelta, timezone
from collections import defaultdict


def handler(event, context):
    """Lambda entry point. Called weekly by EventBridge."""

    sns_topic_arn = os.environ["SNS_TOPIC_ARN"]
    account_label = os.environ["ACCOUNT_LABEL"]
    role_prefix = os.environ.get("ROLE_PREFIX", "gds-aidr")

    cloudtrail = boto3.client("cloudtrail")
    sns = boto3.client("sns", region_name="eu-west-2")

    now = datetime.now(timezone.utc)
    start_time = now - timedelta(days=7)

    # Collect all events for team roles in the past 7 days
    events = []
    paginator_token = None

    while True:
        kwargs = {
            "StartTime": start_time,
            "EndTime": now,
            "MaxResults": 50,
        }
        if paginator_token:
            kwargs["NextToken"] = paginator_token

        response = cloudtrail.lookup_events(**kwargs)

        for event in response.get("Events", []):
            username = event.get("Username", "")
            # Filter to team roles only (not admin, terraform, readonly, security-audit)
            if role_prefix in username and any(
                role in username
                for role in [
                    "data-scientist",
                    "developer",
                    "analyst",
                    "explorer",
                ]
            ):
                cloud_trail_event = json.loads(event.get("CloudTrailEvent", "{}"))
                events.append(
                    {
                        "time": event["EventTime"].strftime("%Y-%m-%d %H:%M"),
                        "username": username,
                        "action": event.get("EventName", "unknown"),
                        "service": cloud_trail_event.get("eventSource", "unknown"),
                        "error": cloud_trail_event.get("errorCode"),
                        "resources": [
                            r.get("ResourceName", "")
                            for r in event.get("Resources", [])
                        ],
                    }
                )

        paginator_token = response.get("NextToken")
        if not paginator_token:
            break

    # Build the summary
    subject = f"AIDR Weekly Digest — {account_label} — {now.strftime('%d %b %Y')}"

    if not events:
        body = (
            f"{subject}\n"
            f"Period: {start_time.strftime('%d %b')} – {now.strftime('%d %b %Y')}\n\n"
            f"No team role activity recorded in {account_label} this week.\n"
        )
    else:
        # Group by user, then by service
        by_user = defaultdict(lambda: defaultdict(list))
        error_count = 0

        for e in events:
            role_name = "unknown"
            for role in ["data-scientist", "developer", "analyst", "explorer"]:
                if role in e["username"]:
                    role_name = role
                    break
            by_user[role_name][e["service"]].append(e)
            if e["error"]:
                error_count += 1

        body_lines = [
            subject,
            f"Period: {start_time.strftime('%d %b')} – {now.strftime('%d %b %Y')}",
            f"Total events: {len(events)}",
            f"Access denied events: {error_count}",
            "",
        ]

        for user, services in sorted(by_user.items()):
            user_total = sum(len(acts) for acts in services.values())
            body_lines.append(f"[{user}] — {user_total} events")

            for service, acts in sorted(services.items()):
                # Summarise actions for this service
                action_counts = defaultdict(int)
                for a in acts:
                    action_counts[a["action"]] += 1

                top_actions = sorted(
                    action_counts.items(), key=lambda x: x[1], reverse=True
                )[:5]
                action_summary = ", ".join(
                    f"{name} ({count})" for name, count in top_actions
                )

                denied = sum(1 for a in acts if a["error"])
                denied_str = f" [{denied} denied]" if denied > 0 else ""

                body_lines.append(
                    f"  {service}: {len(acts)} calls{denied_str}"
                )
                body_lines.append(f"    {action_summary}")

            body_lines.append("")

        # List denied events separately at the bottom
        denied_events = [e for e in events if e["error"]]
        if denied_events:
            body_lines.append("ACCESS DENIED EVENTS:")
            for e in denied_events[:20]:
                body_lines.append(
                    f"  {e['time']} | {e['username']} | {e['action']} | {e['error']}"
                )
            if len(denied_events) > 20:
                body_lines.append(
                    f"  ... and {len(denied_events) - 20} more denied events"
                )
            body_lines.append("")

        body = "\n".join(body_lines)

    # Publish to SNS
    sns.publish(
        TopicArn=sns_topic_arn,
        Subject=subject[:100],
        Message=body,
    )

    return {
        "statusCode": 200,
        "account": account_label,
        "events_processed": len(events),
    }
