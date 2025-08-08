'''to-date-time unit tests'''

import datetime
import time

import pytest

from rosetta_dsl.test.semantic.time_operator.TimeOperatorTest import TimeOperatorTest

def test_to_time_passes():
    '''no doc'''
    to_time_test= TimeOperatorTest(a="11:45:23",b=datetime.time(11,45,23))
    to_time_test.validate_model()

def test_to_time_fails():
    '''no doc'''
    to_date_time_test=TimeOperatorTest(a="14-30-00",b=datetime.time(14,30,0))
    with pytest.raises(Exception):
        to_date_time_test.validate_model()
        
if __name__ == "__main__":
    test_to_time_passes()
    test_to_time_fails()
