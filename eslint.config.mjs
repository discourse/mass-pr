import DiscourseRecommended from "@discourse/lint-configs/eslint";

export default [
  ...DiscourseRecommended,
  {
    ignores: ["mass-pr-workspace/**/*"],
  },
];
