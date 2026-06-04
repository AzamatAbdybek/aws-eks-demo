#!/usr/bin/env python3
"""
generate_jobs.py

Reads changed_projects.txt (produced by the 'Detect Changed Projects' CI job)
and generates a dynamic GitLab CI child pipeline YAML with Terragrunt
fmt / plan / apply / outputs jobs for each changed project.

Usage:
    python3 .gitlab/generate_jobs.py

Output:
    .gitlab/generated-pipeline.gitlab-ci.yml
"""

import os
import sys

try:
    import yaml
except ImportError:
    print("pyyaml not found — install it with: pip install pyyaml")
    sys.exit(1)

CHANGED_PROJECTS_FILE = "changed_projects.txt"
OUTPUT_FILE = ".gitlab/generated-pipeline.gitlab-ci.yml"
JOB_TEMPLATE_FILE = ".gitlab/jobs-templates/project-template.yml"
GENERATED_INCLUDES_DIR = ".gitlab/generated-includes"


def read_changed_projects() -> list[str]:
    """Return a list of changed project folder paths (e.g. ['projects/aws-eks-test1'])."""
    if not os.path.exists(CHANGED_PROJECTS_FILE):
        print(f"[INFO] {CHANGED_PROJECTS_FILE} not found — assuming no projects changed.")
        return []

    with open(CHANGED_PROJECTS_FILE) as fh:
        projects = [line.strip() for line in fh if line.strip()]

    print(f"[INFO] Changed projects detected: {projects}")
    return projects


def load_job_template() -> str:
    """Load the raw job template as a string."""
    with open(JOB_TEMPLATE_FILE) as fh:
        return fh.read()


def render_jobs_for_project(template: str, project_folder: str) -> dict:
    """
    Substitute placeholders in the template and return a dict of CI job definitions.

    Placeholders replaced:
        ${PROJECT_FOLDER} — e.g. projects/aws-eks-test1
        ${PROJECT_NAME}   — e.g. aws-eks-test1  (last path segment)
    """
    project_name = project_folder.rstrip("/").split("/")[-1]
    rendered = template.replace("${PROJECT_FOLDER}", project_folder)
    rendered = rendered.replace("${PROJECT_NAME}", project_name)
    return yaml.safe_load(rendered)


def build_empty_pipeline() -> dict:
    """Return a minimal valid pipeline when there is nothing to deploy."""
    return {
        "stages": ["no-op"],
        "No changed projects": {
            "stage": "no-op",
            "script": ["echo 'No project folders changed — nothing to deploy.'"],
        },
    }


def build_pipeline(projects: list[str]) -> dict:
    """Build the full child pipeline including shared includes + per-project jobs."""
    includes = [
        {"local": f"{GENERATED_INCLUDES_DIR}/main.gitlab-ci.yml"},
        {"local": f"{GENERATED_INCLUDES_DIR}/jobs.gitlab-ci.yml"},
        {"local": f"{GENERATED_INCLUDES_DIR}/rules.gitlab-ci.yml"},
    ]

    pipeline: dict = {"include": includes}
    template = load_job_template()

    for project_folder in projects:
        jobs = render_jobs_for_project(template, project_folder)
        pipeline.update(jobs)

    return pipeline


def main() -> None:
    projects = read_changed_projects()

    if projects:
        pipeline = build_pipeline(projects)
    else:
        pipeline = build_empty_pipeline()

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    with open(OUTPUT_FILE, "w") as fh:
        yaml.dump(pipeline, fh, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"[INFO] Generated pipeline written to: {OUTPUT_FILE}")
    print(f"[INFO] Projects included: {projects if projects else '(none)'}")


if __name__ == "__main__":
    main()
