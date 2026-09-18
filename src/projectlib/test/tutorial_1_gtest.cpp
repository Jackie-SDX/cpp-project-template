/**
 * @file tutorial_1_gtest.cpp
 * @brief Unit tests for tutorial_1.hpp.
 */

#include <gtest/gtest.h>

#include <limits>
#include <stdexcept>
#include <type_traits>

#include "tutorial_1.hpp"

TEST(HelloTest, BasicAssertions)
{
	EXPECT_STRNE("hello", "world");
	EXPECT_EQ(7 * 6, 42);
}

TEST(Tutorial1, Factorial)
{
	EXPECT_EQ(tut1::factorial(0), 1);
	EXPECT_EQ(tut1::factorial(1), 1);
	EXPECT_EQ(tut1::factorial(4), 24);
	static_assert(tut1::factorial(5) == 120);
}

TEST(Tutorial1, RejectsNegativeInput)
{
	EXPECT_THROW(tut1::factorial(-1), std::domain_error);
}

TEST(Tutorial1, DetectsOverflow)
{
	EXPECT_THROW(tut1::factorial(std::numeric_limits<int>::max()), std::overflow_error);
}

int main(int argc, char **argv)
{
	testing::InitGoogleTest(&argc, argv);
	return RUN_ALL_TESTS();
}
