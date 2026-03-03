#!/usr/bin/env python3
import json
import boto3
import sys
from datetime import datetime

def call_bedrock(prompt, max_tokens=4096):
    """Call Amazon Bedrock with Claude model"""
    bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
    
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": max_tokens,
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ]
    })
    
    response = bedrock.invoke_model(
        modelId='us.anthropic.claude-3-5-sonnet-20240620-v1:0',
        body=body
    )
    
    response_body = json.loads(response['body'].read())
    return response_body['content'][0]['text']

def get_pr_diff(pr_number):
    """Get PR diff using GitHub CLI"""
    import subprocess
    result = subprocess.run(
        ['gh', 'pr', 'diff', str(pr_number)],
        capture_output=True,
        text=True
    )
    return result.stdout

def review_pr(pr):
    """Review a single PR"""
    pr_number = pr['number']
    pr_title = pr['title']
    pr_author = pr['author']['login']
    pr_url = pr['url']
    
    print(f"Reviewing PR #{pr_number}: {pr_title}")
    
    # Get the diff
    diff = get_pr_diff(pr_number)
    
    # Create review prompt
    prompt = f"""You are an experienced AWS Solution Architect and Software Developer with 20+ years of experience.

Review this pull request:
- Title: {pr_title}
- Author: {pr_author}
- URL: {pr_url}

Code changes:
```
{diff[:15000]}  # Limit diff size
```

Provide a comprehensive review covering:

1. **Summary**: Brief overview of what this PR does
2. **Code Quality**: Identify inconsistencies, anti-patterns, or quality issues
3. **Security**: Flag any security vulnerabilities or concerns
4. **Testing**: Assess test coverage and testing best practices
5. **Better Approaches**: Challenge the implementation and suggest alternatives based on the actual code
6. **Impact Analysis**: Detail what changes and their potential impact
7. **Recommendation**: Should this be merged, needs review, or needs changes?

Be specific and reference actual code when making recommendations. Do not invent features or suggest unrelated improvements."""

    review = call_bedrock(prompt)
    
    return {
        'pr_number': pr_number,
        'pr_title': pr_title,
        'pr_author': pr_author,
        'pr_url': pr_url,
        'review': review
    }

def main():
    # Load PRs from JSON file
    with open('prs.json', 'r') as f:
        prs = json.load(f)
    
    if not prs:
        print("No open pull requests found.")
        sys.exit(0)
    
    # Review each PR
    reviews = []
    for pr in prs:
        try:
            review = review_pr(pr)
            reviews.append(review)
        except Exception as e:
            print(f"Error reviewing PR #{pr['number']}: {e}")
            continue
    
    # Generate markdown report
    report = f"# Pull Request Review Report\n\n"
    report += f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}\n\n"
    report += f"**Total PRs Reviewed:** {len(reviews)}\n\n"
    report += "---\n\n"
    
    for review in reviews:
        report += f"## PR #{review['pr_number']}: {review['pr_title']}\n\n"
        report += f"**Author:** {review['pr_author']}\n\n"
        report += f"**URL:** {review['pr_url']}\n\n"
        report += review['review']
        report += "\n\n---\n\n"
    
    # Save report
    with open('review_results.md', 'w') as f:
        f.write(report)
    
    print(f"Review complete! {len(reviews)} PRs reviewed.")

if __name__ == '__main__':
    main()
