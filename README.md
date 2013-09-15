About
-----

Этот скрипт автоматически проверяет новые билеты на [poezd.rw.by](https://poezd.rw.by).

Один запущенный экземпляр скрипта проверяет билеты для одной комбинации станции назначения, станции отправления и даты.

Использование
-------------

Требуется:

* [Ruby](http://www.ruby-lang.org/en/) (≥ 1.9.2)
* [Watir](http://watirwebdriver.com)
* [win32-sound](https://rubygems.org/gems/win32-sound) для `:sound`/`:beep` уведомлений

`:sound`, `:beep` и `:msg` уведомления работают только в Windows.

Для запуска скрипта:

	ruby check.rb config.yml

Все уведомления выполняется в едином потоке в том порядке, в каком они указаны в конфиге. Поэтому `:msg` блокирует выполнение остальных уведомлений и дальнейшую работу скрипта в целом до тех пор, пока не закрыто сообщение.

Конфигурация
------------

Файлы конфигурации используют [YAML](http://en.wikipedia.org/wiki/YAML) синтаксис.

##### Обязательные параметры:

* `:from` - Аналог поля `Станция отправления` на сайте.

* `:to` - Аналог поля `Станция назначения` на сайте.

* `:when` - Аналог поля `Дата отправления` на сайте. Формат: `DD.MM.YYYY`.

* `:check` - Содержит названия поездов для проверки. Название должно совпадать с тем, что на сайте. Каждый пукт должен содержать типы билетов, за которыми необходимо следить, для данного поезда:
	* `:ob` - общие;
	* `:s` - сидячие;
	* `:p` - плацкарт;
	* `:k` - купе;
	* `:sv` - СВ;
	* `:m` - мягкие.

##### Необязательные параметры:

* `:delay` - Интервал между проверками (в секундах). По умолчанию 30.

* `:start_page` - Начальная страница с параметрами поиска. Обычно не требуется изменять.

* `:notify` - Содержит типы уведомлений, которые должны применятся:

	* `:email` - Послать имейл.

		Обязательные параметры:
		* `:to` - поле "Кому";
		* `:from`  - поле "От кого";
		* `:server` - адрес SMTP-сервера.

		Необязательные параметры:
		* `:subject` - тема письма, по умолчанию "Уведомление: Новые билеты <from\> - <to\> <when\>";
		* `:login` - имя пользователя SMTP-сервера;
		* `:password` - пароль SMTP-сервера;
		* `:authtype` - тип авторизации SMTP-сервера (`:plain`, `:login` или `:cram_md5`).

	* `:beep` - Системный beep сигнал.

		Необязательные параметры:
		* `:frequency` - частота сигнала (в Hz), по умолчанию 2000;
		* `:duration` - длина сигнала (в мс), по умолчанию 1000;
		* `:times` - количество, по умолчанию 1.

	* `:sound` - Проиграть музыкальный файл.

		Необязательные параметры:
		* `:file` - путь к файлу, по умолчанию "c:\Windows\Media\chimes.wav".

	* `:msg` - Показать системное сообщение.

		Необязательные параметры:
		* `:title` - заголовок окна, по умолчанию "<timestamp\>".

* `:login` - Информация для входа в ["кабинет"](http://poezd.rw.by/wps/portal) пользователя. Проверка билетов будет осуществлятся через раздел ["Покупка билетов"](https://poezd.rw.by/wps/myportal/home/rp/buyTicket), что обеспечивает возможность покупки прямо в этом же браузере при обнаружении билетов.

	* `:usename` - Имя пользователя.

	* `:password` - Пароль.

Copyright
---------

© 2013 Phil Tsarik