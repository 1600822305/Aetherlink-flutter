# Contributing to xterm3

Bug reports, feature requests and pull requests are welcome. File issues at
the [issue tracker](https://github.com/klc/xterm3/issues).

## Contributor License Agreement

Before a pull request can be merged, everyone who authored a commit in it
signs the [Contributor License Agreement](CLA.md) once. You keep the copyright
in your work; the agreement lets the maintainer ship it in xterm3 under the
AGPL and under other terms as well. [CLA.md](CLA.md) explains why.

To sign, post a comment on your pull request that reads exactly:

```
I have read the CLA Document and I hereby sign the CLA
```

A check named **CLA** on the pull request shows who still has to sign. It
matches commits to GitHub accounts by the author email, so make sure the email
your commits carry is [added to your GitHub account][commit-email]. Comment
`recheck` on the pull request to run the check again.

[commit-email]: https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-email-preferences/adding-an-email-address-to-your-github-account

## Before you open a pull request

CI runs these, and a pull request needs them to pass:

```sh
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

- Add a test that fails without your change.
- Describe the change for users in `CHANGELOG.md`, under `## [Unreleased]` at
  the top.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/),
  for example `fix(input): let desktop input methods compose`.
