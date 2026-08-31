#pragma once
#include <cstddef>
#include <iterator>
#include <random>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>

namespace randutils {
std::mt19937& rng();

/**
 * @brief Generates a random string.
 *
 * @param length Length of a string.
 * @param chars Characters that will be used in a string.
 * @return A random string.
 */
std::string string(std::size_t length, const std::string_view chars);

/**
 * @brief Generates a random number between [min, max).
 * @note If min is greater than max, a random number will be generated
 * @note between [max, min).
 *
 * @tparam T Type of number.
 * @param min Min value of number (included).
 * @param max Max value of number (not included).
 * @return A random number between [min, max).
 */
template <typename T>
T number(T min, T max)
{
	if (min == max) {
		return min;
	}
	if (min > max) {
		std::swap(min, max);
	}

	std::mt19937& gen = rng();
	if constexpr (std::is_floating_point<T>::value) {
		std::uniform_real_distribution<T> dis(min, max);
		return dis(gen);
	} else {
		if (min == max - 1) {
			return min;
		}
		std::uniform_int_distribution<T> dis(min, max - 1);
		return dis(gen);
	}
}

/**
 * @brief Generates a random number between [0, max).
 *
 * @tparam T Type of number.
 * @param max Max value of number (not included).
 * @return A random number between [0, max).
 */
template <typename T>
T number(T max)
{
	return number(T { 0 }, max);
}

/**
 * @brief Generates a random number between
 * a) [0, 1) for floats.
 * b) [min, max] for integers.
 *
 * @tparam T Type of number.
 * @return A random number between specified boundaries.
 */
template <typename T>
T number()
{
	std::mt19937& gen = rng();
	if constexpr (std::is_floating_point<T>::value) {
		std::uniform_real_distribution<T> dis(T { 0 }, T { 1 });
		return dis(gen);
	} else {
		std::uniform_int_distribution<T> dis(
			std::numeric_limits<T>::min(), std::numeric_limits<T>::max());
		return dis(gen);
	}
}

/**
 * @brief Picks a random element between @p begin and @p end.
 *
 * @tparam Iter Iterator of container.
 * @param begin Begin iterator.
 * @param end End iterator.
 * @return Iterator to a random element.
 */
template <typename Iter>
Iter choose(Iter begin, Iter end)
{
	std::advance(begin,
		number<decltype(std::distance(begin, end))>(0, std::distance(begin, end)));
	return begin;
}

/**
 * @brief Picks a random element in @p cont and returns a reference to it.
 *
 * @tparam Container Type of container.
 * @param cont Container.
 * @return A reference to a random element.
 */
template <typename Container>
auto choose(const Container& cont) -> decltype(*std::begin(cont))&
{
	return *choose(std::begin(cont), std::end(cont));
}
}