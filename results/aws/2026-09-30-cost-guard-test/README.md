# Cost guards: both terminate real instances (all times IST)

The cost guards ([runbook](../../../docs/aws-runbook.md#cost-guards)) had never fired on a real instance: every earlier stack was destroyed by hand first. This run tests both, on two small instances each (`t3.small`, about $0.02 per hour per instance), in `us-east-1` with an empty account otherwise.

**Result: both guards worked.** The on-instance timer terminated two instances about 5 minutes after launch, and the watchdog Lambda, given instances whose timers were far in the future, terminated them at its first check after its 12 minute deadline.

## Test 1: the on-instance timer

`max_runtime_minutes=5`, watchdog deadline 20 minutes (so the Lambda cannot act first).

| | |
| --- | --- |
| Launched | 14:49:15 (CloudTrail `RunInstances`, two instances) |
| Terminated | between 14:54:12 (both still `running`) and 14:54:34 (both gone): about 5 minutes after launch; the timer is set by cloud-init shortly after boot |
| AWS state reason | `Client.InstanceInitiatedShutdown: Instance initiated shutdown` on both |
| CloudTrail | **no** `TerminateInstances` call between the launch and 14:56 |

The state reason and the absence of an API call are what identify the timer: the operating system shut itself down and EC2 terminated the instance (`instance_initiated_shutdown_behavior = terminate`).

## Test 2: the watchdog Lambda

`max_runtime_minutes=120` (timer never fires in this test) and `guard_grace_minutes=-108`, which makes the Lambda's deadline 12 minutes. The Lambda runs every 10 minutes.

| Time (IST) | Event |
| --- | --- |
| 14:56:20 | two instances launched |
| 14:58:59 (09:28:59 UTC) | Lambda: `2 tagged instance(s), none past 12 min` |
| **15:08:59** | Lambda: `terminating 2 instance(s) older than 12 min: ['i-0eb462d8f1dda2721', 'i-0982991c0066ced7c']` (12 min 39 s after launch) |
| 15:08:59 | CloudTrail `TerminateInstances` by the Lambda's role session (`millionws-bench-c-guard`) |
| 15:09:38 | my observer sees both `terminated` |

AWS records `User initiated (2026-09-30 09:38:59 GMT)` and the state reason `Client.UserInitiatedShutdown`, the wording of an API termination, as opposed to Test 1.

The first four lines in [evidence/lambda_log_lines.txt](evidence/lambda_log_lines.txt) (`none past 165 min`) belong to the Lambda of the Virginia hold run, which used the same function name and log group; they are not from this test.

## What this shows and what it does not

- Both mechanisms work on real instances, in this account, with the Amazon Linux 2023 AMI and the free-plan instance types. The Lambda's IAM permission, the tag filter and the schedule all worked.
- The Lambda was tested with a shortened deadline (12 minutes) by a negative `guard_grace_minutes`; the default deadline (`max_runtime_minutes + 15`) uses the same code path with a different number.
- Not tested: an instance that is stopped rather than running (the Lambda also lists `stopped` and `stopping`), a Spot instance, more than one region at once, and the manual `scripts/kill-bench.sh`.
- **The watchdog terminates every `Project=millionws-bench` instance in its region that is older than its deadline.** A second stack in the same region with a shorter deadline would kill the first stack's instances. This is why this test ran in a region with nothing else in it, and it is now written in the runbook.

## Mistakes in this test

- My first observer script never got a connection to either instance before the timers fired. It was waiting over SSH for the file `/run/systemd/shutdown/scheduled`. That file does exist on Amazon Linux 2023 (I checked on another instance afterwards), so the wait must have failed on the SSH connection, but I did not find out why. The timer test therefore has no SSH-based evidence, only AWS's records above.
- My second observer reported success immediately, because it matched the two instances that the first test had already terminated. I replaced it with one that tracks the new instance IDs.
