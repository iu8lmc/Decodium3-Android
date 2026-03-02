#ifndef COUNTRIES_WORKDED_H_
#define COUNTRIES_WORKDED_H_

#include <QString>
#include <QStringList>

#include "pimpl_h.hpp"

class CountriesWorked final
{
 public:
	explicit CountriesWorked (QStringList const& countryNames);
	~CountriesWorked ();

	void add (QString const& country, QString const& band);
	bool contains (QString const& country, QString const& band = QString {}) const;
		
 private:
	class impl;
	pimpl<impl> m_;
};

#endif
