# stm-firehose

[![Build Status](https://travis-ci.org/bartavelle/stm-firehose.svg?branch=master)](https://travis-ci.org/bartavelle/stm-firehose)
[![stm-firehose on Stackage LTS 3](http://stackage.org/package/stm-firehose/badge/lts-3)](http://stackage.org/lts-3/package/stm-firehose)
[![stm-firehose on Stackage Nightly](http://stackage.org/package/stm-firehose/badge/nightly)](http://stackage.org/nightly/package/stm-firehose)

A fire hose is a component in a message passing system that let clients tap into the message flow. This module provides low level (built on STM channels) and high level (based on conduits) building blocks. It should work with a fixed amount of memory, and has non blocking write operations.

See the haddocs for detailled information.
