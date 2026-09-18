#include "utils.hpp"

#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace cpp_proj
{

std::string wordWrap(const std::string &s, size_t width)
{
	if (width == 0)
		throw std::invalid_argument("wordWrap width must be greater than zero");

	std::stringstream ss(s);
	std::string line;
	std::vector<std::string> lines;

	while (std::getline(ss, line, '\n'))
	{
		while (line.size() > width)
		{
			auto index = line.find_last_of(' ', width);

			if (index == std::string::npos)
			{
				// Split a word exactly at width; do not drop the next character.
				index = width;
				lines.push_back(line.substr(0, index));
				line = line.substr(index);
			}
			else
			{
				lines.push_back(line.substr(0, index));
				line = line.substr(index + 1);
			}
		}
		lines.push_back(line);
	}

	std::string out;
	for (const auto &s2 : lines)
	{
		out += s2 + '\n';
	}

	return out;
}

}  // namespace cpp_proj
