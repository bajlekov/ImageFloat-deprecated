#include "lualib.h"
#include "lauxlib.h"

lua_State* L[64];
int arg_in;
int arg_out;

int lua_thread_call(void* in)
{
	int i = ((int*)in)[0];
	lua_call(L[i], arg_in, arg_out);
	return 0;
}


















