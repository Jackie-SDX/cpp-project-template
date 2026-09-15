/**
 * @file tutorial_1.hpp
 * @author David Gonçalves (11088596+MangaD@users.noreply.github.com)
 * @brief This file contains example code for learning purposes.
 * @version 0.1
 * @date 2023-06-01
 *
 * @copyright Copyright (c) 2023 David Gonçalves
 */

#ifndef TUT1_HPP
#define TUT1_HPP

#include <concepts>
#include <limits>
#include <stdexcept>
#include <type_traits>

/**
 * @brief The namespace for this tutorial.
 */
namespace tut1
{

/**
 * @brief Calculate the factorial of a non-negative integral number.
 *
 * @tparam T Integral input and result type.
 * @param[in] n The non-negative number to calculate the factorial of.
 * @return The calculated factorial.
 * @throws std::domain_error for negative signed inputs.
 * @throws std::overflow_error when the result cannot fit in T.
 */
template <std::integral T>
constexpr T factorial(T n)
{
	static_assert(!std::same_as<T, bool>, "factorial requires a non-bool integral type");

	if constexpr (std::is_signed_v<T>)
	{
		if (n < 0)
			throw std::domain_error("factorial is undefined for negative integers");
	}

	T result{1};
	for (T i{2}; i <= n; ++i)
	{
		if (result > std::numeric_limits<T>::max() / i)
			throw std::overflow_error("factorial result overflows the selected integral type");
		result *= i;
		if (i == n)
			break;
	}
	return result;
}

}  // namespace tut1

#endif
