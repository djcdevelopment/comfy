import datetime as dt
import importlib.util
from pathlib import Path
import sys
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "repo_activity.py"
SPEC = importlib.util.spec_from_file_location("repo_activity", MODULE_PATH)
repo_activity = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
sys.modules[SPEC.name] = repo_activity
SPEC.loader.exec_module(repo_activity)


class RepoActivityTests(unittest.TestCase):
    def test_percentile_is_robust_for_empty_and_small_inputs(self):
        self.assertEqual(repo_activity.percentile([]), 1.0)
        self.assertEqual(repo_activity.percentile([1, 2, 100]), 100.0)

    def test_category_uses_first_matching_prefix(self):
        config = {"categories": [{"name": "Docs", "prefixes": ["docs/"]}]}
        self.assertEqual(repo_activity.category_for("docs/example.md", config), "Docs")
        self.assertEqual(repo_activity.category_for("README.md", config), "Repository root")

    def test_era_assignment_has_future_fallback(self):
        config = {"eras": [{"id": "one", "start": "2026-01-01", "end": "2026-01-02"}]}
        self.assertEqual(repo_activity.era_for("2026-01-02", config), "one")
        self.assertEqual(repo_activity.era_for("2026-03-04", config), "later-2026-03")

    def test_report_eras_adds_future_axis(self):
        config = {"eras": [{"id": "one", "label": "One", "start": "2026-01-01", "end": "2026-01-02"}]}
        future = dt.datetime(2026, 3, 4, tzinfo=dt.timezone.utc)
        files = {"future.md": repo_activity.FileActivity("future.md", 1, "Test", future, future)}
        eras = repo_activity.report_eras(config, files)
        self.assertEqual(eras[-1]["id"], "later-2026-03")
        self.assertEqual(eras[-1]["start"], "2026-03-04")

    def test_publication_path_boundary(self):
        self.assertTrue(repo_activity.is_managed_publication_path("docs/repo-map/activity.json"))
        self.assertTrue(repo_activity.is_managed_publication_path("README.md"))
        self.assertFalse(repo_activity.is_managed_publication_path("network/runtime.py"))

    def test_interactive_report_contains_drilldown_controls(self):
        rendered = repo_activity.interactive_html({
            "source": {"commit": "a" * 40, "first_commit_at": "2026-01-01", "last_commit_at": "2026-01-02", "timezone": "UTC", "commits": 1, "tracked_files": 1, "repository_url": "https://github.com/example/repo", "default_branch": "main"},
            "directories": [{"name": "docs", "files": 1, "size_kb": 1, "is_directory": True, "entrypoint": "docs/README.md"}],
            "daily": [{"date": "2026-01-01"}], "eras": [{"id": "one", "label": "One"}],
            "period_matrix": [{"created_era": "one", "updated_era": "one", "files": 1, "size_kb": 1, "touches": 1, "score": 1}],
            "files": [],
        })
        self.assertIn('data-created="${c}"', rendered)
        self.assertIn("Open README", rendered)
        self.assertIn("activePeriod", rendered)
        self.assertIn("buildTree", rendered)
        self.assertIn("Expand all", rendered)
        self.assertNotIn("<table>", rendered)

    def test_score_rewards_recency_and_touch_frequency(self):
        config = {
            "recency_half_life_days": 14,
            "recent_burst_days": 3,
            "weights": {"recency": 0.45, "touch_frequency": 0.25, "active_lifespan": 0.15, "recent_burst": 0.15},
            "size_weight": {"floor": 0.6, "ceiling": 1.0},
        }
        latest = dt.datetime(2026, 7, 10, tzinfo=dt.timezone.utc)
        hot = repo_activity.FileActivity("hot.md", 1024, "Test", latest - dt.timedelta(days=2), latest, 4, active_days={"2026-07-08", "2026-07-09", "2026-07-10"})
        cold = repo_activity.FileActivity("cold.md", 1024, "Test", latest - dt.timedelta(days=9), latest - dt.timedelta(days=8), 1, active_days={"2026-07-02"})
        files = {hot.path: hot, cold.path: cold}
        repo_activity.compute_scores(config, files, latest)
        self.assertGreater(hot.score, cold.score)


if __name__ == "__main__":
    unittest.main()
