#pragma once
#include <flutter/method_call.h>
#include <flutter/method_result.h>
#include <flutter/encodable_value.h>
#include <memory>

bool HandleSystemMicrophone(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    const std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& reply);
