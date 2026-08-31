#include "random.h"
#include <algorithm>

std::mt19937& randutils::rng()
{
	thread_local static std::mt19937 rng { std::random_device {}() };
	return rng;
}

std::string randutils::string(std::size_t length, const std::string_view chars)
{
	if (chars.empty()) {
		return {};
	}

	std::mt19937& gen = rng();
	std::uniform_int_distribution<std::size_t> dis(0, chars.length() - 1);

	std::string output;
	output.reserve(length);
	std::generate_n(std::back_inserter(output), length, [&chars, &dis, &gen]() -> std::string::value_type {
		return chars[dis(gen)];
	});
	return output;
}