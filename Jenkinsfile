
def runCommand(String command) {
    if (isUnix()) {
        sh command
    } else {
        bat command
    }
}

// Publishing needs a Hex API key; without one `mix hex.publish` blocks on an interactive
// authentication prompt, so the stage says what it skipped instead of hanging the build.
// `hex.publish package`, not bare `hex.publish`: the bare form also builds docs, and ex_doc
// is an umbrella-root dependency a child app run from apps/<app> cannot see. API docs are
// published separately (doc/ is archived; a docs target is not wired up yet).
void publishPackages() {
    if (env.HEX_API_KEY) {
        withEnv(['HEX_BUILD=1']) {
            runCommand 'mix cmd mix hex.publish package --yes'
        }
    } else {
        echo 'HEX_API_KEY is not set - skipping mix hex.publish. The Build stage already built every tarball.'
    }
}

pipeline {

    /*
    setmy.info-elixir
    version 2.2.0 - full toolchain: integration and e2e tiers run against real running
                    instances bracketed by `mix server.start` / `mix server.stop` (OTP release
                    daemons, the failsafe pre-/post-integration-test shape), JUnit XML per app
                    (junit step enabled), documentation coverage (doctor), dependency cycles
                    (xref), CycloneDX SBOM, vulnerability reports and the
                    dependency tree under reports/ (`mix reports`), everything archived.
    version 2.1.0 - re-synced to jenkinsfile-starter 1.2.0 (commit 379e800): the same stages
                    and the same steps, in the same order. Only the placeholder commands are
                    replaced with plain Mix commands (see README.md). The separate Unit /
                    Integration / E2E / Quality / Coverage and docs / System-Acceptance /
                    Package / Hotfix candidate stages that 2.0.0 had are folded back into the
                    starter's Build and Publish stages, where the starter keeps them.
                    RELEASE_TO_DEV / HOTFIX_TO_DEV flags removed with the starter. The
                    starter's numbered learning EXAMPLES (variable demo, sleep, retry, timeout,
                    build-started email) and its PATH setup are left out - build tools are
                    guaranteed on every Jenkins node.
    version 2.0.0 - the Maven-lifecycle emulation was removed. Stages run plain Mix commands
                    (compile, test.unit/test.integration/test.e2e, format, credo, dialyzer,
                    sobelow, deps.audit, coveralls, docs, hex.build/hex.publish, release)
                    instead of the custom tasks that used to live in a dev_tasks app. Servers
                    are no longer started and stopped around the test tiers - each app
                    supervises its own HTTP endpoint.
    version 1.2.0 - migrated from jenkinsfile-starter's then-current Jenkinsfile (commit ad074a6)
    version 1.1.0 - hotfix* branch support, dead MASTER_TO_PRELIVE flag removed
    version 1.0.0 - migrated from jenkinsfile-starter for setmy.info-elixir (Mix umbrella,
                    4-app dependency demo). No GitHub Actions workflow: this Jenkinsfile is
                    this repo's one CI definition.

    jenkinsfile-starter
    version 1.2.0 - release* no longer deploys to DEV: the RELEASE_TO_DEV flag and the release
                    branch of the 'dev' deploy stage are gone. release* deploys to TEST and
                    PRELIVE only. develop -> DEV is unchanged.
    version 1.1.0 - pollSCM instead of cron (build on new commits, not on a timer),
                    quietPeriod + disableConcurrentBuilds(abortPrevious: true) so that a burst
                    of commits becomes one build of the newest change,
                    release* added to Publish/Snapshot (reverted again in 1.2.0: only develop
                    publishes a snapshot)
                    TEST environment renamed to the ADR-0041 canonical name
    version 1.0.1 - fileExists precondition check now actually gates (was a discarded boolean)

    Git branches flow: develop -> feature -> develop -> release -> master

    Building only the newest change
    Every branch is polled for new commits, and commits arrive in bursts. Building each one of
    them is wasted work, so a burst is collapsed twice: quietPeriod folds the commits that have
    not started building yet into a single build, and disableConcurrentBuilds(abortPrevious:
    true) aborts a run that is already in progress as soon as a newer one is ready. What gets
    built is the newest change; the intermediate ones are skipped, not queued. See the options
    block.

    Steps
    1. Enhancement event
    2. feature branch from develop
    3. Enhancements in feature branch - built on new commits, only the newest change is built
    4. After successful build merge to develop - built on new commits, only the newest change is built
    5. Go-No go event: Positive release and release testing decision by DEV and TEST environments
    6. Make release branch - built on new commits, only the newest change is built. Code freeze period started.
    7. Go-No go event: Positive release decision by DEV, TEST, PRELIVE environments
    8. Merge release branch to master - built on new commits, only the newest change is built. Code freeze period ended.
    9. Found a bug in production
    10. hotfix branch from master
    11. Enhancements in hotfix branch - built on new commits, only the newest change is built
    12. Go-No go event: the hotfix is deployed to TEST and PRELIVE, where QA validates and
        verifies it. The decision taken there is either "this is verified" - go to step 15 - or
        "this needs more testing" - go to step 13.
    13. Hotfix merged to develop, when the decision at step 12 asked for more testing.
    14. The development flow continues from step 4, so the fix now also reaches DEV and is
        tested again together with everything else on develop.
    15. Hotfix merged to master. master is what deploys live and tags.

    Automatic deployments to environments: every deployment below is triggered by the build
    itself and gated only by the *_TO_* flags in the environment block. There is no manual
    approval step (no input step) anywhere in this pipeline.

    hotfix* - branched from master, one fix, quick review, then TEST and PRELIVE, where
    QA validates and verifies it. It deliberately does not deploy to DEV: DEV is the
    development integration target and a hotfix integrates nothing. If QA decides the fix
    needs more testing it is merged to develop, and it reaches DEV through the normal
    development flow from there. A hotfix is merged to master to go live, and master is
    what deploys live and tags - a hotfix never goes live directly.

    No pull request builds.

    [5 branches] x [4 environments]. feature* deploys nowhere: it is built and tested only.
    */

    // Known limitation: the four demo endpoints bind fixed localhost ports (config/config.exs),
    // and disableConcurrentBuilds only serialises ONE branch job. Two branch jobs building on
    // the same agent at the same time would collide on those ports; run this pipeline on a
    // single executor per agent, or add a Lockable Resources lock, if that ever happens.
    agent any

    triggers {
        // pollSCM, not cron: cron fires on the timer whether or not anything was pushed, so it
        // builds the same commit over and over. pollSCM asks the SCM every 5 minutes and only
        // triggers when there really are new commits. H spreads the poll across the interval so
        // that all jobs do not hit the SCM in the same second.
        //
        // In a MULTIBRANCH pipeline this is redundant and costs more than it gives: the folder
        // already discovers commits by branch indexing, and this makes every branch job poll the
        // repository separately on top of that - N branches, N pollers, all against one remote.
        // The multibranch way is to leave this out and drive builds from either a webhook (best:
        // instant, no polling at all) or the folder's own "Scan Multibranch Pipeline Triggers".
        // It is kept here because this Jenkinsfile is also meant to work as a single branch job,
        // where nothing else would trigger it.
        pollSCM('H/5 * * * *')
    }

    options {
        buildDiscarder(
            logRotator(
                numToKeepStr: '20',
                artifactNumToKeepStr: '10'
            )
        )

        // Commits arrive in bursts, and building every intermediate commit is wasted work.
        // Two different mechanisms are needed, because they solve two different halves:
        //
        // quietPeriod - the burst that has not started building yet. After a trigger Jenkins
        // holds the queue item this long before it becomes buildable, and every further commit
        // inside the window folds into the same build.
        //
        // Both of these are PER JOB, and in a multibranch pipeline every branch is its own job.
        // A quiet period on one branch does not hold another branch back - their windows count
        // down at the same time - but it does delay every branch by this much, which is very
        // visible when several branches are pushed at once. Keep it short: it only has to cover
        // how long a push burst takes, not how long a build takes. Set it to 0 while testing the
        // pipeline itself.
        //
        // disableConcurrentBuilds(abortPrevious: true) - the build that is already running.
        // Without it Jenkins starts a second run beside the first whenever an executor is
        // free, so several intermediate commits build at once. With it the runs of THIS branch
        // are serialised, and abortPrevious kills the older run the moment a newer one is ready:
        // the newest change wins and the superseded ones never finish. Other branches are not
        // affected - if branches are waiting for each other, that is the executor count, not
        // this option.
        quietPeriod(15)
        disableConcurrentBuilds(abortPrevious: true)
    }

    environment {
        // No PATH setup: Elixir/Erlang/Mix are guaranteed on every Jenkins node.
        // MIX_ENV is deliberately NOT set here: mix.exs' cli/preferred_envs picks the right
        // Mix env per task (test for the test tiers, server lifecycle and reports, dev for the
        // gates), and a global MIX_ENV would override every one of those.

        MASTER_TO_LIVE = 'DEPLOY'

        RELEASE_TO_PRELIVE = 'DEPLOY'
        HOTFIX_TO_PRELIVE = 'DEPLOY'

        DEVELOPMENT_TO_TEST = 'DEPLOY'
        RELEASE_TO_TEST = 'DEPLOY'
        HOTFIX_TO_TEST = 'DEPLOY'

        DEVELOPMENT_TO_DEV = 'DEPLOY'
    }

    stages {
        stage('Inspection') {
            parallel {
                stage('Pre-build') {
                    /*
                    Stage to get into build logs pre build existing environment conditions, versions, getting CI build
                    info into log etc.
                    */
                    steps {
                        echo "Jenkins node: ${env.NODE_NAME}"
                        echo "Operating system: ${isUnix() ? 'Unix/Linux' : 'Windows'}"

                        runCommand 'elixir --version'

                        // fileExists only RETURNS a boolean - as a bare statement its result is
                        // discarded and a missing file fails nothing. It must be wrapped to gate.
                        script {
                            if (!fileExists('README.md')) {
                                error('README.md missing - checkout incomplete or wrong workspace directory')
                            }
                        }

                        echo 'Pre build inspection and precondition check. Build tools must be installed on the agent.'
                    }
                }
                /*
                Stage to install build required tools. Build dependencies.
                */
                stage('Build tools') {
                    steps {
                        echo 'Build tools installation and preparation (setup, config)'
                        runCommand 'mix local.hex --force'
                        runCommand 'mix local.rebar --force'
                        // After local.hex, not in Pre-build: the two run in parallel, and on a
                        // fresh agent hex.info does not exist until Hex is installed.
                        runCommand 'mix hex.info'
                    }
                }
            }
        }

        stage('Preparation') {
            parallel {
                /*
                Stage to install language and source, language code dependencies.
                */
                stage('Install') {
                    steps {
                        echo 'Preparing the software to be built. Installation commands go here.'
                        runCommand 'mix deps.get'
                        echo 'Put here build configuration commands'
                        // Nothing to configure: config/ is checked in and mix.exs is the build
                        // configuration. The lockfile is checked for orphaned entries instead.
                        runCommand 'mix deps.unlock --check-unused'
                    }
                }
            }
        }

        /*
        Stage to build code with with executing all needed steps to measure different type of code quality.
        */
        stage('Build') {
            steps {
                echo 'Cleaning command, because in some cases shared directories can have previous build garbage'
                runCommand 'mix clean'

                echo 'Put here resource copy commands'
                echo 'Nothing to copy: priv/ ships as-is and config/ is read at compile and boot time'

                echo 'Put here compilation commands. Can be omitted.'
                runCommand 'mix format --check-formatted'
                runCommand 'mix compile --warnings-as-errors'
                // test-compile: the same compile under the test Mix env, so that test-only
                // compile errors surface here, before any test tier runs.
                withEnv(['MIX_ENV=test']) {
                    runCommand 'mix compile --warnings-as-errors'
                }

                echo 'Put here unit tests'
                // JUNIT_REPORT_FILE: one JUnit file per tier under reports/junit/, otherwise
                // every tier overwrites the previous one and the junit step sees only the last.
                withEnv(['JUNIT_REPORT_FILE=unit.xml']) {
                    runCommand 'mix test.unit'
                }

                echo 'Put here integration tests. Previous steps can be merged here.'
                // pre-integration-test / integration-test / post-integration-test, the way
                // Maven's failsafe brackets them: the releases are built and started as
                // daemons, the tier runs against them (--no-start: no second copy in the test
                // VM), the daemons are stopped. `mix test.integration` is the same three in one
                // alias; spelled out here so each is its own line in the build log. A failing
                // tier leaves the daemons up - post { always } below stops them.
                runCommand 'mix server.start'
                withEnv(['JUNIT_REPORT_FILE=integration.xml']) {
                    runCommand 'mix test --only integration --no-start'
                }
                runCommand 'mix server.stop'

                echo 'Put here mutation tests'
                echo 'Not wired in yet'

                echo 'Put here reporting builds steps can include (unit tests coverage, mutation test coverage, findbugs, vuln. checks, )'
                echo 'Containing here findbug/stopbug, check style, dependencies vulnerability checks, docs gen, etc'
                // Gates first (each fails the build on a finding), then the documents.
                runCommand 'mix credo --strict'
                runCommand 'mix dialyzer'
                runCommand 'mix xref.cycles'
                runCommand 'mix doctor'
                runCommand 'mix sobelow'
                runCommand 'mix audit'
                // `mix reports`: ExDoc API docs (doc/), coverage over all three tiers as HTML
                // (cover/), CycloneDX SBOM, mix_audit + Sobelow JSON vulnerability reports and
                // the dependency tree (reports/). Coverage runs the tiers itself, with the same
                // server lifecycle around them. (`mix coverage.xml` gives the SonarQube generic
                // XML instead, when a Sonar step is wired in.)
                withEnv(['JUNIT_REPORT_FILE=coverage.xml']) {
                    runCommand 'mix reports'
                }

                echo 'Put here site deploy'
                echo 'Not wired to a target yet - doc/, cover/ and reports/ are archived by post { always } below'

                echo 'Put here e2e tests'
                // pre-e2e-test / e2e / post-e2e-test, same shape as the integration tier.
                runCommand 'mix server.start'
                withEnv(['JUNIT_REPORT_FILE=e2e.xml']) {
                    runCommand 'mix test --only e2e --no-start'
                }
                runCommand 'mix server.stop'

                echo 'Put here system tests'
                echo 'Put here acceptance tests'

                echo 'Put here packaging'
                // One Hex tarball per app. HEX_BUILD switches the in_umbrella sibling deps to
                // their published Hex names; see apps/demo_module_c/mix.exs for why it is not
                // always on.
                withEnv(['HEX_BUILD=1']) {
                    runCommand 'mix cmd mix hex.build'
                }

                echo 'Put here local publishing'
                echo 'Nothing to publish locally: Hex has no local repository, the tarballs above are the local result'
            }
        }

        // comparator: 'REGEXP' below is not decoration. The default GLOB comparator's `*` does
        // not cross a `/`, so `branch 'release*'` does NOT match `release/1.2.0` - every publish
        // and deployment for that branch is then silently skipped. It is easy to miss, because
        // `devel*` keeps working: `develop` has no separator in it.
        stage('Publish') {
            parallel {
                /*
                Stage to push or upload build packages/artifacts to file storage systems.
                */
                stage('Release') {
                    when {
                        branch 'master'
                        // changeset "**/file/to/be/changed"
                    }
                    steps {
                        echo 'Put here software release steps'
                        publishPackages()
                    }
                }
                stage('Snapshot') {
                    when {
                        branch pattern: 'devel.*', comparator: 'REGEXP'
                    }
                    steps {
                        echo 'Put here software snapshot publishing steps'
                        // Hex has no snapshot concept: a version can be published exactly once,
                        // so publishing every develop build would fail from the second build
                        // on. The snapshot IS the set of tarballs the Build stage produced and
                        // post { always } archives; publishing happens from master.
                        echo 'No Hex snapshot publishing - the Build stage tarballs are archived as the snapshot'
                    }
                }
                stage('Release reports') {
                    when {
                        branch 'master'
                    }
                    steps {
                        echo 'Put here reports publishing steps'
                        echo 'Not wired to a target yet - doc/, cover/ and reports/ are archived by post { always } below'
                    }
                }
                stage('Snapshot reports') {
                    when {
                        branch pattern: 'devel.*', comparator: 'REGEXP'
                    }
                    steps {
                        echo 'Put here reports publishing steps'
                        echo 'Not wired to a target yet - doc/, cover/ and reports/ are archived by post { always } below'
                    }
                }
            }
        }
        stage('Deploy') {
            parallel {
                /*
                Stages to deploy/install artifacts to different environments.
                One OTP release per app, built for the target environment (`mix release.all`).
                Installing them on a real host is not wired up yet.
                withEnv, not a `VAR=value command` shell prefix: that prefix is Bourne-shell
                syntax and does nothing under bat on a Windows agent.
                */
                stage('dev') {
                    when {
                        environment name: 'DEVELOPMENT_TO_DEV', value: 'DEPLOY'
                        branch pattern: 'devel.*', comparator: 'REGEXP'
                    }
                    steps {
                        echo 'Put here software development installations steps'
                        withEnv(['MIX_ENV=dev']) {
                            runCommand 'mix release.all --overwrite'
                        }
                    }
                }
                stage('test') {
                    when {
                        anyOf {
                            allOf {
                                environment name: 'DEVELOPMENT_TO_TEST', value: 'DEPLOY'
                                branch pattern: 'devel.*', comparator: 'REGEXP'
                            }
                            allOf {
                                environment name: 'RELEASE_TO_TEST', value: 'DEPLOY'
                                branch pattern: 'release.*', comparator: 'REGEXP'
                            }
                            allOf {
                                environment name: 'HOTFIX_TO_TEST', value: 'DEPLOY'
                                branch pattern: 'hotfix.*', comparator: 'REGEXP'
                            }
                        }
                    }
                    steps {
                        echo 'Put here software test installations steps'
                        withEnv(['MIX_ENV=test']) {
                            runCommand 'mix release.all --overwrite'
                        }
                    }
                }
                stage('prelive') {
                    when {
                        anyOf {
                            allOf {
                                environment name: 'RELEASE_TO_PRELIVE', value: 'DEPLOY'
                                branch pattern: 'release.*', comparator: 'REGEXP'
                            }
                            allOf {
                                environment name: 'HOTFIX_TO_PRELIVE', value: 'DEPLOY'
                                branch pattern: 'hotfix.*', comparator: 'REGEXP'
                            }
                        }
                    }
                    steps {
                        echo 'Put here software prelive installations steps'
                        withEnv(['MIX_ENV=prelive']) {
                            runCommand 'mix release.all --overwrite'
                        }
                    }
                }
                stage('live') {
                    when {
                        environment name: 'MASTER_TO_LIVE', value: 'DEPLOY'
                        branch 'master'
                    }
                    steps {
                        echo 'Put here software production installations steps'
                        withEnv(['MIX_ENV=live']) {
                            runCommand 'mix release.all --overwrite'
                        }
                    }
                }
            }
        }
        /*
        Stage to make SCM tag. As all results are succeeded then tag reflects FULL build success.
        */
        stage('Tag') {
            when {
                environment name: 'MASTER_TO_LIVE', value: 'DEPLOY'
                branch 'master'
            }
            steps {
                echo 'Put here tagging. For example: '
                echo 'smi-new-tag 1.2.3'
                echo 'And logic to get tag from source files for example.'
            }
        }
    }

    post {
        always {
            // Stops the release daemons a failed integration/e2e tier left behind; idempotent.
            runCommand 'mix server.stop'
            junit allowEmptyResults: true, testResults: 'reports/junit/*.xml'
            archiveArtifacts artifacts: 'cover/**, doc/**, reports/**, apps/*/*.tar', allowEmptyArchive: true, fingerprint: true
        }

        success {
            emailext (
                subject: "Jenkins job: $JOB_NAME, build: $BUILD_NUMBER type: SUCCESSFUL",
                body: "Job: $JOB_NAME, build: $BUILD_NUMBER, url: ${env.BUILD_URL}, git: ${env.GIT_URL}, branch: ${env.GIT_BRANCH} SUCCESSFUL post step",
                recipientProviders: [[$class: 'DevelopersRecipientProvider']]
            )
        }

        failure {
            emailext (
                subject: "Jenkins job: $JOB_NAME, build: $BUILD_NUMBER type: FAILED",
                body: "Job: $JOB_NAME, build: $BUILD_NUMBER, url: ${env.BUILD_URL}, git: ${env.GIT_URL}, branch: ${env.GIT_BRANCH}  FAILED post step",
                recipientProviders: [[$class: 'DevelopersRecipientProvider']]
            )
        }
    }
}
