#!/usr/bin/env python3
"""
Gitea AI Code Review — 调用 new-api 网关审查代码改动
用法: python3 ai_review.py <diff_file> <repo_owner> <repo_name> <commit_sha>

告知方式（不再推飞书）:
  1. 审查结论写入报告文件 .review/review-<sha>.md（随 workflow 提交回仓库）
  2. 设置 Gitea commit status（CI 状态标识）
"""
import json
import os
import sys
import urllib.request

def call_ai(messages, model="deepseek-v4-pro"):
    """调用 new-api 网关（OpenAI 兼容）"""
    api_url = os.environ.get("AI_REVIEW_API_URL", "http://192.168.1.69:3000/v1/chat/completions")
    api_key = os.environ.get("AI_REVIEW_API_KEY", "")
    req = urllib.request.Request(
        api_url,
        data=json.dumps({
            "model": model,
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": 2000,
        }).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = json.loads(resp.read())
            return data["choices"][0]["message"]["content"]
    except Exception as e:
        return f"[AI 调用失败] {e}"

def set_commit_status(owner, repo, sha, state, description, target_url=""):
    """设置 Gitea commit status（显示在提交页）"""
    token = os.environ.get("GITHUB_TOKEN", "")
    gitea_url = os.environ.get("GITEA_URL", "http://192.168.1.69:13000")
    if not token:
        return
    url = f"{gitea_url}/api/v1/repos/{owner}/{repo}/statuses/{sha}"
    payload = json.dumps({
        "state": state,
        "context": "ai-review",
        "description": description[:120],
        "target_url": target_url,
    }).encode()
    req = urllib.request.Request(url, data=payload, method="POST",
                                 headers={"Content-Type": "application/json",
                                          "Authorization": f"token {token}"})
    try:
        urllib.request.urlopen(req, timeout=15)
    except Exception as e:
        print(f"[status 设置失败] {e}")

def main():
    diff_file = sys.argv[1]
    owner = sys.argv[2]
    repo = sys.argv[3]
    sha = sys.argv[4]

    with open(diff_file, "r", errors="replace") as f:
        diff = f.read()

    if not diff.strip():
        print("无代码改动，跳过审查")
        set_commit_status(owner, repo, sha, "success", "AI 审查：无代码改动")
        return

    MAX_DIFF = 30000
    if len(diff) > MAX_DIFF:
        diff = diff[:MAX_DIFF] + f"\n...[已截断，共 {len(diff)} 字符]"

    system_prompt = """你是资深代码审查专家。审查以下 git diff，重点关注：
1. 逻辑错误、bug、安全隐患
2. 代码质量、可维护性问题
3. 性能问题
4. 是否符合最佳实践

输出格式（简洁中文，使用 Markdown）：
## 审查结论: ✅ 通过 / ⚠️ 有问题 / ❌ 严重问题

### 问题列表
- **[严重程度: 高/中/低]** 文件:行 - 问题描述

### 改进建议
- 具体建议

保持客观专业，只报告真实问题，不吹毛求疵。"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"仓库: {owner}/{repo}\n提交: {sha}\n\n代码改动 diff:\n```diff\n{diff}\n```"},
    ]

    result = call_ai(messages)
    print(result)

    # 判断结论状态
    state = "success"
    if "❌" in result:
        state = "failure"
    elif "⚠️" in result:
        state = "pending"  # 有问题但非阻塞，用 pending 或 success 均可

    # 写入报告文件（workflow 会提交回仓库）
    os.makedirs(".review", exist_ok=True)
    with open(f".review/review-{sha[:8]}.md", "w") as f:
        f.write(f"# AI 代码审查报告\n\n- **仓库**: {owner}/{repo}\n- **提交**: {sha}\n- **时间**: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n---\n\n{result}\n")

    # 设置 commit status
    set_commit_status(owner, repo, sha, state, "AI 审查完成")

if __name__ == "__main__":
    main()
