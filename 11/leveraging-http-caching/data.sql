INSERT INTO book(id, title, text, created_at, updated_at)
VALUES (1, 'Authentication and Authorization', 'Authentication and authorization are required for a Web page that should
be limited to certain users. *Authentication* is about verifying whether
someone is who they claim to be. It usually involves a username and a
password, but may include any other methods of demonstrating identity, such
as a smart card, fingerprints, etc. *Authorization* is finding out if the
person, once identified (i.e. authenticated), is permitted to manipulate
specific resources. This is usually determined by finding out if that
person is of a particular role that has access to the resources.

Yii has a built-in authentication/authorization (auth) framework which is
easy to use and can be customized for special needs.

The central piece in the Yii auth framework is a pre-declared *user
application component* which is an object implementing the [IWebUser]
interface. The user component represents the persistent identity
information for the current user. We can access it at any place using
\`Yii::app()->user\`.

Using the user component, we can check if a user is logged in or not via
[CWebUser::isGuest]; we can [login|CWebUser::login] and
[logout|CWebUser::logout] a user; we can check if the user can perform
specific operations by calling [CWebUser::checkAccess]; and we can also
obtain the [unique identifier|CWebUser::name] and other persistent identity
information about the user.

Defining Identity Class
-----------------------

As mentioned above, authentication is about validating the identity of the user. A typical Web application authentication implementation usually involves using a username and password combination to verify a user\'s identity. However, it may include other methods and different implementations may be required. To accommodate varying authentication methods, the Yii auth framework introduces the identity class.

We define an identity class which contains the actual authentication logic. The identity class should implement the [IUserIdentity] interface. Different identity classes can be
implemented for different authentication approaches (e.g. OpenID, LDAP, Twitter OAuth, Facebook Connect). A good start when writing your own implementation is to extend [CUserIdentity] which is a base class for the authentication approach using a username and password.

The main work in defining an identity class is the implementation of the
[IUserIdentity::authenticate] method. This is the method used to encapsulate the main details of the authentication approach. An identity class may also declare
additional identity information that needs to be persistent during the user
session.

#### An Example

In the following example, we use an identity class to demonstrate using a database approach to authentication. This is typical in Web applications. A user will enter their username and password into a login form, and then we validate these credentials, using [ActiveRecord](/doc/guide/database.ar), against a user table in the database . There are actually a few things being demonstrated in this single example:

1. The implementation of the \`authenticate()\` method to use the database to validate credentials.
2. Overriding the \`CUserIdentity::getId()\` method to return the \`_id\` property because the default implementation returns the username as the ID.
3. Using the \`setState()\` ([CBaseUserIdentity::setState]) method to demonstrate storing other information that can easily be retrieved upon subsequent requests.

~~~
[php]
class UserIdentity extends CUserIdentity
{
	private $_id;
	public function authenticate()
	{
		$record=User::model()->findByAttributes(array(\'username\'=>$this->username));
		if($record===null)
			$this->errorCode=self::ERROR_USERNAME_INVALID;
		else if($record->password!==crypt($this->password,$record->password))
			$this->errorCode=self::ERROR_PASSWORD_INVALID;
		else
		{
			$this->_id=$record->id;
			$this->setState(\'title\', $record->title);
			$this->errorCode=self::ERROR_NONE;
		}
		return !$this->errorCode;
    }

	public function getId()
	{
		return $this->_id;
	}
}
~~~

When we cover login and logout in the next section, we\'ll see that we pass this identity class into the login method for a user. Any information that we store in a state (by calling [CBaseUserIdentity::setState]) will be passed to [CWebUser], which in turn will store them in a persistent storage, such as session.
This information can then be accessed like properties of [CWebUser]. In our example, we stored the user title information via \`$this->setState(\'title\', $record->title);\`. Once we complete our login process, we can obtain the \`title\` information of the current user by simply using \`Yii::app()->user->title\`.

> Info: By default, [CWebUser] uses session as persistent storage for user
identity information. If cookie-based login is enabled (by setting
[CWebUser::allowAutoLogin] to be true), the user identity information may
also be saved in cookie. Make sure you do not declare sensitive information
(e.g. password) to be persistent.

### Storing passwords in the database

Secure storage of user passwords in a database requires some care. An attacker that has stolen your user table (or a backup of it) can recover passwords using standard techniques if you don\'t protect against them. In particular you should salt the password before hashing and use a hash function that takes the attacker a long time to compute. The above code example uses the built-in PHP \`crypt()\` function which, with appropriate use, returns hashes that are very hard to crack.

To learn more about these topics please read.

- [PHP \`crypt()\` function](http://php.net/manual/en/function.crypt.php)
- Yii Wiki article [Use crypt() for password storage](http://www.yiiframework.com/wiki/425)


Login and Logout
----------------

Now that we have seen an example of creating a user identity, we use this to help ease the implementation of our needed login and logout actions. The following code demonstrates how this is accomplished:

~~~
[php]
// Login a user with the provided username and password.
$identity=new UserIdentity($username,$password);
if($identity->authenticate())
	Yii::app()->user->login($identity);
else
	echo $identity->errorMessage;
......
// Logout the current user
Yii::app()->user->logout();
~~~

Here we are creating a new UserIdentity object and passing in the authentication credentials (i.e. the \`$username\` and \`$password\` values submitted by the user) to its constructor. We then simply call the \`authenticate()\` method. If successful, we pass the identity information into the [CWebUser::login] method, which will store the identity information into persistent storage (PHP session by default) for retrieval upon subsequent requests. If the authentication fails, we can interrogate the \`errorMessage\` property for more information as to why it failed.

Whether or not a user has been authenticated can easily be checked throughout the application by using \`Yii::app()->user->isGuest\`. If using persistent storage like session (the default) and/or a cookie (discussed below) to store the identity information, the user can remain logged in upon subsequent requests. In this case, we don\'t need to use the UserIdentity class and the entire login process upon each request. Rather CWebUser will automatically take care of loading the identity information from this persistent storage and will use it to determine whether \`Yii::app()->user->isGuest\` returns true or false.

Cookie-based Login
------------------

By default, a user will be logged out after a certain period of inactivity,
depending on the [session configuration](http://www.php.net/manual/en/session.configuration.php).
To change this behavior, we can set the [allowAutoLogin|CWebUser::allowAutoLogin]
property of the user component to be true and pass a duration parameter to
the [CWebUser::login] method. The user will then remain logged in for
the specified duration, even if he closes his browser window. Note that
this feature requires the user\'s browser to accept cookies.

~~~
[php]
// Keep the user logged in for 7 days.
// Make sure allowAutoLogin is set true for the user component.
Yii::app()->user->login($identity,3600*24*7);
~~~

As we mentioned above, when cookie-based login is enabled, the states
stored via [CBaseUserIdentity::setState] will be saved in the cookie as well.
The next time when the user is logged in, these states will be read from
the cookie and made accessible via \`Yii::app()->user\`.

Although Yii has measures to prevent the state cookie from being tampered
on the client side, we strongly suggest that security sensitive information be not
stored as states. Instead, these information should be restored on the server
side by reading from some persistent storage on the server side (e.g. database).

In addition, for any serious Web applications, we recommend using the following
strategy to enhance the security of cookie-based login.

* When a user successfully logs in by filling out a login form, we generate and
store a random key in both the cookie state and in persistent storage on server side
(e.g. database).

* Upon a subsequent request, when the user authentication is being done via the cookie information, we compare the two copies
of this random key and ensure a match before logging in the user.

* If the user logs in via the login form again, the key needs to be re-generated.

By using the above strategy, we eliminate the possibility that a user may re-use
an old state cookie which may contain outdated state information.

To implement the above strategy, we need to override the following two methods:

* [CUserIdentity::authenticate()]: this is where the real authentication is performed.
If the user is authenticated, we should re-generate a new random key, and store it
in the database as well as in the identity states via [CBaseUserIdentity::setState].

* [CWebUser::beforeLogin()]: this is called when a user is being logged in.
We should check if the key obtained from the state cookie is the same as the one
from the database.




Access Control Filter
---------------------

Access control filter is a preliminary authorization scheme that checks if
the current user can perform the requested controller action. The
authorization is based on user\'s name, client IP address and request types.
It is provided as a filter named as
["accessControl"|CController::filterAccessControl].

> Tip: Access control filter is sufficient for simple scenarios. For more
complex access control you may use role-based access (RBAC), which we will cover in the next subsection.

To control the access to actions in a controller, we install the access
control filter by overriding [CController::filters] (see
[Filter](/doc/guide/basics.controller#filter) for more details about
installing filters).

~~~
[php]
class PostController extends CController
{
	......
	public function filters()
	{
		return array(
			\'accessControl\',
		);
	}
}
~~~

In the above, we specify that the [access
control|CController::filterAccessControl] filter should be applied to every
action of \`PostController\`. The detailed authorization rules used by the
filter are specified by overriding [CController::accessRules] in the
controller class.

~~~
[php]
class PostController extends CController
{
	......
	public function accessRules()
	{
		return array(
			array(\'deny\',
				\'actions\'=>array(\'create\', \'edit\'),
				\'users\'=>array(\'?\'),
			),
			array(\'allow\',
				\'actions\'=>array(\'delete\'),
				\'roles\'=>array(\'admin\'),
			),
			array(\'deny\',
				\'actions\'=>array(\'delete\'),
				\'users\'=>array(\'*\'),
			),
		);
	}
}
~~~

The above code specifies three rules, each represented as an array. The
first element of the array is either \`\'allow\'\` or \`\'deny\'\` and the other
name-value pairs specify the pattern parameters of the rule. The rules defined above are interpreted as follows: the \`create\` and \`edit\` actions cannot be executed by anonymous
users; the \`delete\` action can be executed by users with \`admin\` role;
and the \`delete\` action cannot be executed by anyone.

The access rules are evaluated one by one in the order they are specified.
The first rule that matches the current pattern (e.g. username, roles,
client IP, address) determines the authorization result. If this rule is an \`allow\`
rule, the action can be executed; if it is a \`deny\` rule, the action cannot
be executed; if none of the rules matches the context, the action can still
be executed.

> Tip: To ensure an action does not get executed under certain contexts,
> it is beneficial to always specify a matching-all \`deny\` rule at the end
> of rule set, like the following:
> ~~~
> [php]
> return array(
>     // ... other rules...
>     // the following rule denies \'delete\' action for all contexts
>     array(\'deny\',
>         \'actions\'=>array(\'delete\'),
>     ),
> );
> ~~~
> The reason for this rule is because if none of the rules matches a context, then the action will continue to be executed.


An access rule can match the following context parameters:

   - [actions|CAccessRule::actions]: specifies which actions this rule
matches. This should be an array of action IDs. The comparison is case-insensitive.

   - [controllers|CAccessRule::controllers]: specifies which controllers this rule
matches. This should be an array of controller IDs. The comparison is case-insensitive.

   - [users|CAccessRule::users]: specifies which users this rule matches.
The current user\'s [name|CWebUser::name] is used for matching. The comparison
is case-insensitive. Three special characters can be used here:

	   - \`*\`: any user, including both anonymous and authenticated users.
	   - \`?\`: anonymous users.
	   - \`@\`: authenticated users.

   - [roles|CAccessRule::roles]: specifies which roles that this rule matches.
This makes use of the [role-based access control](/doc/guide/topics.auth#role-based-access-control)
feature to be described in the next subsection. In particular, the rule
is applied if [CWebUser::checkAccess] returns true for one of the roles.
Note, you should mainly use roles in an \`allow\` rule because by definition,
a role represents a permission to do something. Also note, although we use the
term \`roles\` here, its value can actually be any auth item, including roles,
tasks and operations.

   - [ips|CAccessRule::ips]: specifies which client IP addresses this rule
matches.

   - [verbs|CAccessRule::verbs]: specifies which request types (e.g.
\`GET\`, \`POST\`) this rule matches. The comparison is case-insensitive.

   - [expression|CAccessRule::expression]: specifies a PHP expression whose value
indicates whether this rule matches. In the expression, you can use variable \`$user\`
which refers to \`Yii::app()->user\`.


Handling Authorization Result
-----------------------------

When authorization fails, i.e., the user is not allowed to perform the
specified action, one of the following two scenarios may happen:

   - If the user is not logged in and if the [loginUrl|CWebUser::loginUrl]
property of the user component is configured to be the URL of the login
page, the browser will be redirected to that page. Note that by default,
[loginUrl|CWebUser::loginUrl] points to the \`site/login\` page.

   - Otherwise an HTTP exception will be displayed with error code 403.

When configuring the [loginUrl|CWebUser::loginUrl] property, one can
provide a relative or absolute URL. One can also provide an array which
will be used to generate a URL by calling [CWebApplication::createUrl]. The
first array element should specify the
[route](/doc/guide/basics.controller#route) to the login controller
action, and the rest name-value pairs are GET parameters. For example,

~~~
[php]
array(
	......
	\'components\'=>array(
		\'user\'=>array(
			// this is actually the default value
			\'loginUrl\'=>array(\'site/login\'),
		),
	),
)
~~~

If the browser is redirected to the login page and the login is
successful, we may want to redirect the browser back to the page that
caused the authorization failure. How do we know the URL for that page? We
can get this information from the [returnUrl|CWebUser::returnUrl] property
of the user component. We can thus do the following to perform the
redirection:

~~~
[php]
Yii::app()->request->redirect(Yii::app()->user->returnUrl);
~~~

Role-Based Access Control
-------------------------

Role-Based Access Control (RBAC) provides a simple yet powerful
centralized access control. Please refer to the [Wiki
article](http://en.wikipedia.org/wiki/Role-based_access_control) for more
details about comparing RBAC with other more traditional access control
schemes.

Yii implements a hierarchical RBAC scheme via its
[authManager|CWebApplication::authManager] application component. In the
following ,we first introduce the main concepts used in this scheme; we
then describe how to define authorization data; at the end we show how to
make use of the authorization data to perform access checking.

### Overview

A fundamental concept in Yii\'s RBAC is *authorization item*. An
authorization item is a permission to do something (e.g. creating new blog
posts, managing users). According to its granularity and targeted audience,
authorization items can be classified as *operations*,
*tasks* and *roles*. A role consists of tasks, a task
consists of operations, and an operation is a permission that is atomic.
For example, we can have a system with \`administrator\` role which consists
of \`post management\` task and \`user management\` task. The \`user management\`
task may consist of \`create user\`, \`update user\` and \`delete user\`
operations. For more flexibility, Yii also allows a role to consist of
other roles or operations, a task to consist of other tasks, and an
operation to consist of other operations.

An authorization item is uniquely identified by its name.

An authorization item may be associated with a *business rule*. A
business rule is a piece of PHP code that will be executed when performing
access checking with respect to the item. Only when the execution returns
true, will the user be considered to have the permission represented by the
item. For example, when defining an operation \`updatePost\`, we would like
to add a business rule that checks if the user ID is the same as the post\'s
author ID so that only the author himself can have the permission to update
a post.

Using authorization items, we can build up an *authorization
hierarchy*. An item \`A\` is a parent of another item \`B\` in the
hierarchy if \`A\` consists of \`B\` (or say \`A\` inherits the permission(s)
represented by \`B\`). An item can have multiple child items, and it can also
have multiple parent items. Therefore, an authorization hierarchy is a
partial-order graph rather than a tree. In this hierarchy, role items sit
on top levels, operation items on bottom levels, while task items in
between.

Once we have an authorization hierarchy, we can assign roles in this
hierarchy to application users. A user, once assigned with a role, will
have the permissions represented by the role. For example, if we assign the
\`administrator\` role to a user, he will have the administrator permissions
which include \`post management\` and \`user management\` (and the
corresponding operations such as \`create user\`).

Now the fun part starts. In a controller action, we want to check if the
current user can delete the specified post. Using the RBAC hierarchy and
assignment, this can be done easily as follows:

~~~
[php]
if(Yii::app()->user->checkAccess(\'deletePost\'))
{
	// delete the post
}
~~~

Configuring Authorization Manager
---------------------------------

Before we set off to define an authorization hierarchy and perform access
checking, we need to configure the
[authManager|CWebApplication::authManager] application component. Yii
provides two types of authorization managers: [CPhpAuthManager] and
[CDbAuthManager]. The former uses a PHP script file to store authorization
data, while the latter stores authorization data in database. When we
configure the [authManager|CWebApplication::authManager] application
component, we need to specify which component class to use and what are the
initial property values for the component. For example,

~~~
[php]
return array(
	\'components\'=>array(
		\'db\'=>array(
			\'class\'=>\'CDbConnection\',
			\'connectionString\'=>\'sqlite:path/to/file.db\',
		),
		\'authManager\'=>array(
			\'class\'=>\'CDbAuthManager\',
			\'connectionID\'=>\'db\',
		),
	),
);
~~~

We can then access the [authManager|CWebApplication::authManager]
application component using \`Yii::app()->authManager\`.

Defining Authorization Hierarchy
--------------------------------

Defining authorization hierarchy involves three steps: defining
authorization items, establishing relationships between authorization
items, and assigning roles to application users. The
[authManager|CWebApplication::authManager] application component provides a
whole set of APIs to accomplish these tasks.

To define an authorization item, call one of the following methods,
depending on the type of the item:

   - [CAuthManager::createRole]
   - [CAuthManager::createTask]
   - [CAuthManager::createOperation]

Once we have a set of authorization items, we can call the following
methods to establish relationships between authorization items:

   - [CAuthManager::addItemChild]
   - [CAuthManager::removeItemChild]
   - [CAuthItem::addChild]
   - [CAuthItem::removeChild]

And finally, we call the following methods to assign role items to
individual users:

   - [CAuthManager::assign]
   - [CAuthManager::revoke]

Below we show an example about building an authorization hierarchy with
the provided APIs:

~~~
[php]
$auth=Yii::app()->authManager;

$auth->createOperation(\'createPost\',\'create a post\');
$auth->createOperation(\'readPost\',\'read a post\');
$auth->createOperation(\'updatePost\',\'update a post\');
$auth->createOperation(\'deletePost\',\'delete a post\');

$bizRule=\'return Yii::app()->user->id==$params["post"]->authID;\';
$task=$auth->createTask(\'updateOwnPost\',\'update a post by author himself\',$bizRule);
$task->addChild(\'updatePost\');

$role=$auth->createRole(\'reader\');
$role->addChild(\'readPost\');

$role=$auth->createRole(\'author\');
$role->addChild(\'reader\');
$role->addChild(\'createPost\');
$role->addChild(\'updateOwnPost\');

$role=$auth->createRole(\'editor\');
$role->addChild(\'reader\');
$role->addChild(\'updatePost\');

$role=$auth->createRole(\'admin\');
$role->addChild(\'editor\');
$role->addChild(\'author\');
$role->addChild(\'deletePost\');

$auth->assign(\'reader\',\'readerA\');
$auth->assign(\'author\',\'authorB\');
$auth->assign(\'editor\',\'editorC\');
$auth->assign(\'admin\',\'adminD\');
~~~

Once we have established this hierarchy, the [authManager|CWebApplication::authManager] component (e.g.
[CPhpAuthManager], [CDbAuthManager]) will load the authorization
items automatically. Therefore, we only need to run the above code one time, and NOT for every request.

> Info: While the above example looks long and tedious, it is mainly for
> demonstrative purposes. Developers will usually need to develop some administrative user
> interfaces so that end users can establish an authorization
> hierarchy more intuitively.


Using Business Rules
--------------------

When we are defining the authorization hierarchy, we can associate a role, a task or an operation with a so-called *business rule*. We may also associate a business rule when we assign a role to a user. A business rule is a piece of PHP code that is executed when we perform access checking. The returning value of the code is used to determine if the role or assignment applies to the current user. In the example above, we associated a business rule with the \`updateOwnPost\` task. In the business rule we simply check if the current user ID is the same as the specified post\'s author ID. The post information in the \`$params\` array is supplied by developers when performing access checking.


### Access Checking

To perform access checking, we first need to know the name of the
authorization item. For example, to check if the current user can create a
post, we would check if he has the permission represented by the
\`createPost\` operation. We then call [CWebUser::checkAccess] to perform the
access checking:

~~~
[php]
if(Yii::app()->user->checkAccess(\'createPost\'))
{
	// create post
}
~~~

If the authorization rule is associated with a business rule which
requires additional parameters, we can pass them as well. For example, to
check if a user can update a post, we would pass in the post data in the \`$params\`:

~~~
[php]
$params=array(\'post\'=>$post);
if(Yii::app()->user->checkAccess(\'updateOwnPost\',$params))
{
	// update post
}
~~~


### Using Default Roles

Many Web applications need some very special roles that would be assigned to
every or most of the system users. For example, we may want to assign some
privileges to all authenticated users. It poses a lot of maintenance trouble
if we explicitly specify and store these role assignments. We can exploit
*default roles* to solve this problem.

A default role is a role that is implicitly assigned to every user. We do not
need to explicitly assign it to a user.
When [CWebUser::checkAccess] is invoked, default roles will be checked first as if they are
assigned to the user.

Default roles must be declared in the [CAuthManager::defaultRoles] property.
For example, the following configuration declares two roles to be default roles: \`authenticated\` and \`admin\`.

~~~
[php]
return array(
	\'components\'=>array(
		\'authManager\'=>array(
			\'class\'=>\'CDbAuthManager\',
			\'defaultRoles\'=>array(\'authenticated\', \'admin\'),
		),
	),
);
~~~

Because a default role is assigned to every user, it usually needs to be
associated with a business rule that determines whether the role
really applies to the user. For example, the following code defines two
roles, \`authenticated\` and \`admin\`, which effectively apply to authenticated
users and users with the username \`admin\`, respectively.

~~~
[php]
$bizRule=\'return !Yii::app()->user->isGuest;\';
$auth->createRole(\'authenticated\', \'authenticated user\', $bizRule);

$bizRule=\'return Yii::app()->user->name === "admin";\';
$auth->createRole(\'admin\', \'admin user\', $bizRule);
~~~

> Info: Since version 1.1.11 the \`$params\` array passed to a business rule has a key named
> \`userId\` whose value is the id of the user the business rule is checked for.
> You would need this if you call [CDbAuthManager::checkAccess()] or [CPhpAuthManager::checkAccess()] in places
> where \`Yii::app()->user\` is not available or not the user you are checking access for.', 1355655146, 1355655146),
(2, 'Console Applications', 'Console applications are mainly used to perform offline work needed by an
online Web application, such as code generation, search index compiling, email
sending, etc. Yii provides a framework for writing console applications in
an object-oriented way. It allows a console application to access
the resources (e.g. DB connections) that are used by an online Web application.


Overview
--------

Yii represents each console task in terms of a [command|CConsoleCommand].
A console command is written as a class extending from [CConsoleCommand].

When we use the \`yiic webapp\` tool to create an initial skeleton Yii application,
we may find two files under the \`protected\` directory:

* \`yiic\`: this is an executable script used on Linux/Unix;
* \`yiic.bat\`: this is an executable batch file used on Windows.

In a console window, we can enter the following commands:

~~~
cd protected
yiic help
~~~

This will display a list of available console commands. By default, the available
commands include those provided by Yii framework (called **system commands**)
and those developed by users for individual applications (called **user commands**).

To see how to use a command, we can execute

~~~
yiic help <command-name>
~~~

And to execute a command, we can use the following command format:

~~~
yiic <command-name> [parameters...]
~~~


Creating Commands
-----------------

Console commands are stored as class files under the directory specified by
[CConsoleApplication::commandPath]. By default, this refers to the directory
\`protected/commands\`.

A console command class must extend from [CConsoleCommand]. The class name
must be of format \`XyzCommand\`, where \`Xyz\` refers to the command name with
the first letter in upper case. For example, a \`sitemap\` command must use
the class name \`SitemapCommand\`. Console command names are case-sensitive.

> Tip: By configuring [CConsoleApplication::commandMap], one can also have
> command classes in different naming conventions and located in different
> directories.

To create a new command, one often needs to override [CConsoleCommand::run()]
or develop one or several command actions (to be explained in the next section).

When executing a console command, the [CConsoleCommand::run()] method will be
invoked by the console application. Any console command parameters will be passed
to the method as well, according to the following signature of the method:

~~~
[php]
public function run($args) { ... }
~~~

where \`$args\` refers to the extra parameters given in the command line.

Within a console command, we can use \`Yii::app()\` to access the console application
instance, through which we can also access resources such as database connections
(e.g. \`Yii::app()->db\`). As we can tell, the usage is very similar to what we can
do in a Web application.

> Info: Starting from version 1.1.1, we can also create global commands that
are shared by **all** Yii applications on the same machine. To do so, define
an environment variable named \`YII_CONSOLE_COMMANDS\` which should point to
an existing directory. We can then put our global command class files under
this directory.


Console Command Action
----------------------

> Note: The feature of console command action has been available since version 1.1.5.

A console command often needs to handle different command line parameters, some required,
some optional. A console command may also need to provide several sub-commands to handle
different sub-tasks. These work can be simplified using console command actions.

A console command action is a method in a console command class.
The method name must be of the format \`actionXyz\`, where \`Xyz\` refers to the action
name with the first letter in upper-case. For example, a method \`actionIndex\` defines
an action named \`index\`.

To execute a specific action, we use the following console command format:

~~~
yiic <command-name> <action-name> --option1=value1 --option2=value2 ...
~~~

The additional option-value pairs will be passed as named parameters to the action method.
The value of a \`xyz\` option will be passed as the \`$xyz\` parameter of the action method.
For example, if we define the following command class:

~~~
[php]
class SitemapCommand extends CConsoleCommand
{
    public function actionIndex($type, $limit=5) { ... }
    public function actionInit() { ... }
}
~~~

Then, the following console commands will all result in calling \`actionIndex(\'News\', 5)\`:

~~~
yiic sitemap index --type=News --limit=5

// $limit takes default value
yiic sitemap index --type=News

// $limit takes default value
// because \'index\' is a default action, we can omit the action name
yiic sitemap --type=News

// the order of options does not matter
yiic sitemap index --limit=5 --type=News
~~~

If an option is given without value (e.g. \`--type\` instead of \`--type=News\`), the corresponding
action parameter value will be assumed to be boolean \`true\`.

> Note: We do not support alternative option formats such as
> \`--type News\`, \`-t News\`.

A parameter can take an array value by declaring it with array type hinting:

~~~
[php]
public function actionIndex(array $types) { ... }
~~~

To supply the array value, we simply repeat the same option in the command line as needed:

~~~
yiic sitemap index --types=News --types=Article
~~~

The above command will call \`actionIndex(array(\'News\', \'Article\'))\` ultimately.


Starting from version 1.1.6, Yii also supports using anonymous action parameters and global options.

Anonymous parameters refer to those command line parameters not in the format of options.
For example, in a command \`yiic sitemap index --limit=5 News\`, we have an anonymous parameter whose value
is \`News\` while the named parameter \`limit\` is taking the value 5.

To use anonymous parameters, a command action must declare a parameter named as \`$args\`. For example,

~~~
[php]
public function actionIndex($limit=10, $args=array()) {...}
~~~

The \`$args\` array will hold all available anonymous parameter values.

Global options refer to those command line options that are shared by all actions in a command.
For example, in a command that provides several actions, we may want every action to recognize
an option named as \`verbose\`. While we can declare \`$verbose\` parameter in every action method,
a better way is to declare it as a **public member variable** of the command class, which turns \`verbose\`
into a global option:

~~~
[php]
class SitemapCommand extends CConsoleCommand
{
	public $verbose=false;
	public function actionIndex($type) {...}
}
~~~

The above code will allow us to execute a command with a \`verbose\` option:

~~~
yiic sitemap index --verbose=1 --type=News
~~~


Exit Codes
----------

> Note: The possibility to return exit codes in console commands has been available since version 1.1.11.

When running console commands automatically, via cronjob or using a continuous integration server, it is
always interesting if the command ran successfully or if there were errors.
This can be done by checking the exit code a process returns on exit.

These codes are integer values between 0 and 254 (this is the range in [php world](http://www.php.net/manual/en/function.exit.php)),
where 0 should be returned on success and all other values greater than 0 will indicate an error.

In an action method or in the \`run()\` method of your console command you can return an integer value
to exit your application with an exit code.
Example:

~~~
[php]
if (/* error */) {
    return 1; // exit with error code 1
}
// ... do something ...
return 0; // exit successfully
~~~

When there is no return value, application will exit with code 0.


Customizing Console Applications
--------------------------------

By default, if an application is created using the \`yiic webapp\` tool, the configuration
for the console application will be \`protected/config/console.php\`. Like a Web application
configuration file, this file is a PHP script which returns an array representing the
property initial values for a console application instance. As a result, any public property
of [CConsoleApplication] can be configured in this file.

Because console commands are often created to serve for the Web application, they need
to access the resources (such as DB connections) that are used by the latter. We can do so
in the console application configuration file like the following:

~~~
[php]
return array(
	......
	\'components\'=>array(
		\'db\'=>array(
			......
		),
	),
);
~~~

As we can see, the format of the configuration is very similar to what we do in
a Web application configuration. This is because both [CConsoleApplication] and [CWebApplication]
share the same base class.', 1355655146, 1355655146),
(3, 'Error Handling', 'Yii provides a complete error handling framework based on the PHP 5
exception mechanism. When the application is created to handle an incoming
user request, it registers its [handleError|CApplication::handleError]
method to handle PHP warnings and notices; and it registers its
[handleException|CApplication::handleException] method to handle uncaught
PHP exceptions. Consequently, if a PHP warning/notice or an uncaught
exception occurs during the application execution, one of the error
handlers will take over the control and start the necessary error handling
procedure.

> Tip: The registration of error handlers is done in the application\'s
constructor by calling PHP functions
[set_exception_handler](http://www.php.net/manual/en/function.set-exception-handler.php)
and [set_error_handler](http://www.php.net/manual/en/function.set-error-handler.php).
If you do not want Yii to handle the errors and exceptions, you may define
constant \`YII_ENABLE_ERROR_HANDLER\` and \`YII_ENABLE_EXCEPTION_HANDLER\` to
be false in the [entry script](/doc/guide/basics.entry).

By default, [handleError|CApplication::handleError] (or
[handleException|CApplication::handleException]) will raise an
[onError|CApplication::onError] event (or
[onException|CApplication::onException] event). If the error (or exception)
is not handled by any event handler, it will call for help from the
[errorHandler|CErrorHandler] application component.

Raising Exceptions
------------------

Raising exceptions in Yii is not different from raising a normal PHP
exception. One uses the following syntax to raise an exception when needed:

~~~
[php]
throw new ExceptionClass(\'ExceptionMessage\');
~~~

Yii defines three exception classes: [CException], [CDbException] and
[CHttpException]. [CException] is a generic exception class. [CDbException]
represents an exception that is caused by some DB-related operations.
[CHttpException] represents an exception that should be displayed to end users
and carries a [statusCode|CHttpException::statusCode] property representing an HTTP
status code. The class of an exception determines how it should be
displayed, as we will explain next.

> Tip: Raising a [CHttpException] exception is a simple way of reporting
errors caused by user misoperation. For example, if the user provides an
invalid post ID in the URL, we can simply do the following to show a 404
error (page not found):
~~~
[php]
// if post ID is invalid
throw new CHttpException(404,\'The specified post cannot be found.\');
~~~

Displaying Errors
-----------------

When an error is forwarded to the [CErrorHandler] application component,
it chooses an appropriate view to display the error. If the error is meant
to be displayed to end users, such as a [CHttpException], it will use a
view named \`errorXXX\`, where \`XXX\` stands for the HTTP status code (e.g.
400, 404, 500). If the error is an internal one and should only be
displayed to developers, it will use a view named \`exception\`. In the
latter case, complete call stack as well as the error line information will
be displayed.

> Info: When the application runs in [production
mode](/doc/guide/basics.entry#debug-mode), all errors including those internal
ones will be displayed using view \`errorXXX\`. This is because the call
stack of an error may contain sensitive information. In this case,
developers should rely on the error logs to determine what is the real
cause of an error.

[CErrorHandler] searches for the view file corresponding to a view in the
following order:

   1. \`WebRoot/themes/ThemeName/views/system\`: this is the \`system\` view
directory under the currently active theme.

   2. \`WebRoot/protected/views/system\`: this is the default \`system\` view
directory for an application.

   3. \`yii/framework/views\`: this is the standard system view directory
provided by the Yii framework.

Therefore, if we want to customize the error display, we can simply create
error view files under the system view directory of our application or
theme. Each view file is a normal PHP script consisting of mainly HTML
code. For more details, please refer to the default view files under the
framework\'s \`view\` directory.


Handling Errors Using an Action
-------------------------------

Yii allows using a [controller action](/doc/guide/basics.controller#action)
to handle the error display work. To do so, we should configure the error handler
in the application configuration as follows:

~~~
[php]
return array(
	......
	\'components\'=>array(
		\'errorHandler\'=>array(
			\'errorAction\'=>\'site/error\',
		),
	),
);
~~~

In the above, we configure the [CErrorHandler::errorAction] property to be the route
\`site/error\` which refers to the \`error\` action in \`SiteController\`. We may use a different
route if needed.

We can write the \`error\` action like the following:

~~~
[php]
public function actionError()
{
	if($error=Yii::app()->errorHandler->error)
		$this->render(\'error\', $error);
}
~~~

In the action, we first retrieve the detailed error information from [CErrorHandler::error].
If it is not empty, we render the \`error\` view together with the error information.
The error information returned from [CErrorHandler::error] is an array with the following fields:

 * \`code\`: the HTTP status code (e.g. 403, 500);
 * \`type\`: the error type (e.g. [CHttpException], \`PHP Error\`);
 * \`message\`: the error message;
 * \`file\`: the name of the PHP script file where the error occurs;
 * \`line\`: the line number of the code where the error occurs;
 * \`trace\`: the call stack of the error;
 * \`source\`: the context source code where the error occurs.

> Tip: The reason we check if [CErrorHandler::error] is empty or not is because
the \`error\` action may be directly requested by an end user, in which case there is no error.
Since we are passing the \`$error\` array to the view, it will be automatically expanded
to individual variables. As a result, in the view we can access directly the variables such as
\`$code\`, \`$type\`.


Message Logging
---------------

A message of level \`error\` will always be logged when an error occurs. If
the error is caused by a PHP warning or notice, the message will be logged
with category \`php\`; if the error is caused by an uncaught exception, the
category would be \`exception.ExceptionClassName\` (for [CHttpException] its
[statusCode|CHttpException::statusCode] will also be appended to the
category). One can thus exploit the [logging](/doc/guide/topics.logging)
feature to monitor errors happened during application execution.', 1355655146, 1355655146);