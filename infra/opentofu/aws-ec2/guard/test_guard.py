import datetime
import unittest

import guard

NOW = datetime.datetime(2026, 9, 30, 12, 0, tzinfo=datetime.timezone.utc)


def inst(id, age_min):
    return {"InstanceId": id, "LaunchTime": NOW - datetime.timedelta(minutes=age_min)}


class FakeEC2:
    def __init__(self, instances):
        self.instances, self.terminated, self.filters = instances, None, None

    def get_paginator(self, name):
        assert name == "describe_instances"
        return self

    def paginate(self, Filters):
        self.filters = Filters
        return [{"Reservations": [{"Instances": self.instances[:1]}, {"Instances": self.instances[1:]}]}]

    def terminate_instances(self, InstanceIds):
        self.terminated = InstanceIds


class GuardTest(unittest.TestCase):
    def test_expired_boundary(self):
        got = guard.expired([inst("a", 254), inst("b", 255), inst("c", 256), inst("d", 900)], NOW, 255)
        self.assertEqual(got, ["c", "d"])

    def test_terminates_only_old_and_only_tagged(self):
        ec2 = FakeEC2([inst("young", 10), inst("old", 400), inst("older", 1000)])
        out = guard.handler(ec2=ec2, now=NOW)
        self.assertEqual(ec2.terminated, ["old", "older"])
        self.assertEqual(out["terminated"], ["old", "older"])
        self.assertIn({"Name": "tag:Project", "Values": ["millionws-bench"]}, ec2.filters)

    def test_nothing_to_do_makes_no_terminate_call(self):
        ec2 = FakeEC2([inst("young", 10)])
        guard.handler(ec2=ec2, now=NOW)
        self.assertIsNone(ec2.terminated)

    def test_no_instances(self):
        ec2 = FakeEC2([])
        self.assertEqual(guard.handler(ec2=ec2, now=NOW)["checked"], 0)
        self.assertIsNone(ec2.terminated)


if __name__ == "__main__":
    unittest.main()
