TEMPLATE = app

QT *= testlib
QT -= gui
CONFIG += c++14 console
CONFIG += proof proofcore proof-gtest
macx:CONFIG -= app_bundle
