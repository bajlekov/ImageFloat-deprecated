//#include <stdio.h>
//#include <math.h>
#include <SDL/SDL_thread.h>
#include <luajit-2.0/lualib.h>
#include <luajit-2.0/lauxlib.h>

SDL_mutex* mut;
lua_State* L[64];
int arg_in;
int arg_out;

int lua_thread_call(void* in)
{
	int* p = (int*) in;

	SDL_mutexP(mut);
		int i = p[0];	//local copy calling unique lua threads
		p[0]++;			//increment instance number
	SDL_mutexV(mut);

	lua_call(L[i], arg_in, arg_out);
	
	return 0;
}


















