import { describe, expect, test } from 'vitest';
import { anonimizar, semParametros } from '../src/lib/registro.js';
import { classificar } from '../src/lib/regras.js';

describe('registro do relato', () => {
  test('tira CPF, matrícula, e-mail e números longos', () => {
    const t = anonimizar('cpf 123.456.789-01 mat 20990000001 id 12345 fulano@sou.ufac.br status 504');
    expect(t).not.toMatch(/123\.456|20990000001|12345|fulano/);
    expect(t).toContain('status 504');
  });
  test('endereço sem parâmetros nem domínio', () => {
    expect(semParametros('https://portal.ufac.br/aluno/aluno/nota/nota.action?matricula=12345')).toBe('/aluno/aluno/nota/nota.action');
    expect(semParametros('/aluno/x/98765.action#a')).toBe('/aluno/x/#.action');
  });
});

describe('sessão do Portal', () => {
  test('"Alterar Senha" do Portal do Usuário pede senha nova (não é senha errada nem login feito)', () => {
    expect(classificar('portal', 'https://portal.ufac.br/usuario/usuario/usuario.action')).toBe('trocarSenha');
    expect(classificar('professor', 'https://portal.ufac.br/usuario/usuario/usuario.action')).toBe('trocarSenha');
    expect(classificar('portal', 'https://portal.ufac.br/aluno/index.action')).toBe('logado');
    expect(classificar('portal', 'https://portal.ufac.br/aluno/login.action')).toBe('naLogin');
  });
});
