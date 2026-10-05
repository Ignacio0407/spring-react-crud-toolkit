export default interface User {
  id: number;
  username: string;
  password: string,
  authority: Authority,
  roles?: string[];
}

export enum Authority {
    ADMIN = "ADMIN", PLAYER = "PLAYER"
}

export const emptyUser: User = 
{id: 0, username: "", password: "", authority: Authority.PLAYER, roles: []};

export interface BaseUser {
  id: number;
  username: string;
  password?: string,
  authority?: Authority,
  roles?: string[];
}