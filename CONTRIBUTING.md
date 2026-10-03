# Contributing

Contributions are always welcome, no matter how large or small!

We want this community to be friendly and respectful to each other. Please follow it in all your interactions with the project. Before contributing, please read the [code of conduct](./CODE_OF_CONDUCT.md).

## Development workflow

This project is a monorepo managed using [Yarn workspaces](https://yarnpkg.com/features/workspaces). It contains the following packages:

- The library package in the root directory.
- An example app in the `example/` directory.

To get started with the project, first remove the `workspaces` in root package.json

run `yarn` in the root directory + in `example` folder:

```sh
yarn
```

after that change `workspaces` in root package.json back

> Since the project relies on Yarn workspaces, you cannot use [`npm`](https://github.com/npm/cli) for development.

The [example app](/example/) demonstrates usage of the library. You need to run it to test any changes you make.

It is configured to use the local version of the library, so any changes you make to the library's source code will be reflected in the example app. Changes to the library's JavaScript code will be reflected in the example app without a rebuild, but native code changes will require a rebuild of the example app.

If you want to use Android Studio or XCode to edit the native code, you can open the `example/android` or `example/ios` directories respectively in those editors. To edit the Objective-C or Swift files, open `example/ios/VideoTrimExample.xcworkspace` in XCode and find the source files at `Pods > Development Pods > react-native-video-trim`.

To edit the Java or Kotlin files, open `example/android` in Android studio and find the source files at `react-native-video-trim` under `Android`.

You can use various commands from the root directory to work with the project.

To start the packager:

```sh
yarn example start
```

To run the example app on Android:

```sh
yarn example android
```

To run the example app on iOS:

```sh
yarn example ios
```

To confirm that the app is running with the new architecture, you can check the Metro logs for a message like this:

```sh
Running "VideoTrimExample" with {"fabric":true,"initialProps":{"concurrentRoot":true},"rootTag":1}
```

Note the `"fabric":true` and `"concurrentRoot":true` properties.

Make sure your code passes TypeScript and ESLint. Run the following to verify:

```sh
yarn typecheck
yarn lint
```

To fix formatting errors, run the following:

```sh
yarn lint --fix
```

Remember to add tests for your change if possible. Run the unit tests by:

```sh
yarn test
```

### Commit message convention

We follow the [conventional commits specification](https://www.conventionalcommits.org/en) for our commit messages:

- `fix`: bug fixes, e.g. fix crash due to deprecated method.
- `feat`: new features, e.g. add new method to the module.
- `refactor`: code refactor, e.g. migrate from class components to hooks.
- `docs`: changes into documentation, e.g. add usage example for the module..
- `test`: adding or updating tests, e.g. add integration tests using detox.
- `chore`: tooling changes, e.g. change CI config.

Our pre-commit hooks verify that your commit message matches this format when committing.

### Linting and tests

[ESLint](https://eslint.org/), [Prettier](https://prettier.io/), [TypeScript](https://www.typescriptlang.org/)

We use [TypeScript](https://www.typescriptlang.org/) for type checking, [ESLint](https://eslint.org/) with [Prettier](https://prettier.io/) for linting and formatting the code, and [Jest](https://jestjs.io/) for testing.

Our pre-commit hooks verify that the linter and tests pass when committing.

### Changesets

Every pull request that changes published behaviour must include a changeset. A changeset is a small markdown file in `.changeset/` that says which version bump the change needs and what to write in the changelog. To add one, run:

```sh
yarn changeset
```

Pick the bump and write one or two sentences for users of the library:

- `patch`: bug fixes.
- `minor`: new features, new options or new APIs.
- `major`: breaking changes.

Commit the generated `.changeset/<random-name>.md` file with your change. The command needs Node.js 22.11 or newer (`.nvmrc`). Always use `yarn changeset`, not `npx changeset`: the bare CLI does not see the library package because of the `example` workspace. You can also write the file by hand:

```md
---
'react-native-video-trim': patch
---

Fix the crash when merging clips without an audio track.
```

Changes that users do not see (docs, CI, tests, the example app) do not need a changeset.

Write the summary for library users, not reviewers: describe the behaviour change, not the implementation. If a pull request contains several unrelated user visible changes, add one changeset per change. You can edit or delete a changeset until it is released.

### Publishing to npm

Releases are automated by the [release workflow](.github/workflows/release.yml) with [Changesets](https://github.com/changesets/changesets). Nobody publishes from a local machine.

1. When pull requests with changesets are merged into `master`, the workflow opens (or updates) the release pull request `chore: release vX.Y.Z` from branch `release/vX.Y.Z`. It bumps `version` in `package.json`, adds the new section to `CHANGELOG.md` and removes the consumed changesets; the pull request body shows the release notes. If later changesets raise the version again, that pull request is closed and replaced by one for the new version.
2. Review that pull request. To reword an entry, edit the changeset on `master`: the release branch is rebuilt on every run, so edits made there are lost when more changesets land.
3. Merging it publishes the new version to npm with provenance, through npm trusted publishing, and creates the GitHub release `vX.Y.Z` from the `CHANGELOG.md` section.

A version with a prerelease suffix such as `9.0.0-beta.0` is published under the `next` dist-tag and marked as a prerelease on GitHub.

### Scripts

The `package.json` file contains various scripts for common tasks:

- `yarn`: setup project by installing dependencies.
- `yarn typecheck`: type-check files with TypeScript.
- `yarn lint`: lint files with ESLint.
- `yarn test`: run unit tests with Jest.
- `yarn changeset`: add a changeset for your change.
- `yarn example start`: start the Metro server for the example app.
- `yarn example android`: run the example app on Android.
- `yarn example ios`: run the example app on iOS.

### Sending a pull request

> **Working on your first pull request?** You can learn how from this _free_ series: [How to Contribute to an Open Source Project on GitHub](https://app.egghead.io/playlists/how-to-contribute-to-an-open-source-project-on-github).

When you're sending a pull request:

- Prefer small pull requests focused on one change.
- Verify that linters and tests are passing.
- Add a changeset (`yarn changeset`) if the change is visible to users of the library.
- Review the documentation to make sure it looks good.
- Follow the pull request template when opening a pull request.
- For pull requests that change the API or implementation, discuss with maintainers first by opening an issue.
